#!/usr/bin/env python3
import asyncio, websockets, json, logging, ssl, argparse, sys, os
import aiohttp
from aiohttp import web
from urllib.parse import quote, unquote
logging.basicConfig(level=logging.INFO, format='[%(asctime)s] [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)
IPC_SOCKET_PATH = os.environ.get('IPC_SOCKET_PATH', '/tmp/plex-discord-ipc.sock')

class PlexAPIHandler:
    """Handle Plex API HTTP requests (search, etc.)"""
    def __init__(self, plex_ip='192.168.50.80', plex_port='32400', plex_token=None):
        self.plex_url = f'http://{plex_ip}:{plex_port}'
        self.plex_token = (plex_token or os.environ.get('PLEX_TOKEN', '')).rstrip('&')
        self.session = None

    async def init(self):
        """Initialize aiohttp session"""
        self.session = aiohttp.ClientSession()

    async def close(self):
        """Close aiohttp session"""
        if self.session:
            await self.session.close()

    async def search(self, query):
        """Search Plex library"""
        try:
            if not query:
                return {'error': 'Query cannot be empty'}

            # Manually construct URL to avoid aiohttp URL-encoding the & in the token
            # The token contains a literal & character that must not be encoded as %26
            url = f'{self.plex_url}/search?query={query.lower()}&X-Plex-Token={self.plex_token}'
            headers = {
                'Accept': 'application/json',
            }

            logger.info(f'[PlexAPI] Searching for: {query}')
            logger.info(f'[PlexAPI] Full URL (with token): {url}')
            logger.info(f'[PlexAPI] Token value: {self.plex_token}')

            # Increased timeout to 60 seconds
            timeout = aiohttp.ClientTimeout(total=60)
            async with self.session.get(url, headers=headers, timeout=timeout) as response:
                if response.status == 200:
                    data = await response.json()
                    metadata = data.get('MediaContainer', {}).get('Metadata', [])
                    logger.info(f'[PlexAPI] Found {len(metadata)} results')
                    return data.get('MediaContainer', {})
                else:
                    logger.error(f'[PlexAPI] Search failed: status {response.status}')
                    return {'error': f'Plex API returned status {response.status}'}

        except asyncio.TimeoutError:
            logger.error('[PlexAPI] Search timeout')
            return {'error': 'Plex search timed out'}
        except aiohttp.ClientError as e:
            logger.error(f'[PlexAPI] Connection error: {e}')
            return {'error': f'Connection error: {e}'}
        except Exception as e:
            logger.error(f'[PlexAPI] Unexpected error: {e}')
            return {'error': f'Unexpected error: {e}'}

    async def get_server_identity(self):
        """Get Plex server identity including machine ID"""
        try:
            import xml.etree.ElementTree as ET
            url = f'{self.plex_url}/identity?X-Plex-Token={self.plex_token}'

            timeout = aiohttp.ClientTimeout(total=10)
            async with self.session.get(url, timeout=timeout) as response:
                if response.status == 200:
                    # The /identity endpoint returns XML, not JSON
                    text = await response.text()
                    root = ET.fromstring(text)
                    machine_id = root.get('machineIdentifier', '')
                    if machine_id:
                        logger.info(f'[PlexAPI] Server machine ID: {machine_id}')
                        return {'machineIdentifier': machine_id}
                    else:
                        logger.error(f'[PlexAPI] No machineIdentifier in response')
                        return {'error': 'No machineIdentifier in response'}
                else:
                    logger.error(f'[PlexAPI] Failed to get server identity: status {response.status}')
                    return {'error': f'Failed to get server identity: {response.status}'}
        except Exception as e:
            logger.error(f'[PlexAPI] Error getting server identity: {e}')
            return {'error': str(e)}

class PlexDiscordServer:
    def __init__(self, host='0.0.0.0', port=8765, ssl_context=None):
        self.host, self.port, self.clients, self.ssl_context = host, port, set(), ssl_context
        self.port_type = 'discord' if port == 8765 else 'browser'
        self.ipc_reader = None
        self.ipc_writer = None
        self.discord_bot = None  # Store Discord bot connection for responses
        self.pending_requests = {}  # Map request id to response handler
    async def connect_ipc(self):
        try:
            reader, writer = await asyncio.open_unix_connection(IPC_SOCKET_PATH)
            self.ipc_reader, self.ipc_writer = reader, writer
            logger.info(f'Connected to IPC socket for {self.port_type} instance')
            asyncio.create_task(self.read_ipc_messages())
        except Exception as e:
            logger.warning(f'Could not connect to IPC socket: {e}')
    async def read_ipc_messages(self):
        while True:
            try:
                line = await self.ipc_reader.readuntil(b'\n')
                if not line: break
                msg = json.loads(line.decode())
                # If this is a response (has id and status), route back to Discord bot
                if msg.get('id') and msg.get('status') and self.discord_bot:
                    logger.debug(f'Routing response back to Discord bot: {msg}')
                    try: await self.discord_bot.send(json.dumps(msg))
                    except: pass
                else:
                    await self.broadcast_to_clients(msg)
            except Exception as e:
                logger.debug(f'IPC read error: {e}')
                break
    async def send_to_ipc(self, message):
        if self.ipc_writer:
            try:
                self.ipc_writer.write((json.dumps(message) + '\n').encode())
                await self.ipc_writer.drain()
            except Exception as e:
                logger.debug(f'IPC send error: {e}')
    async def broadcast_to_clients(self, cmd):
        if not self.clients: return
        disconnected = set()
        for client in self.clients:
            try:
                await client.send(json.dumps(cmd))
                logger.debug(f'Sent command via IPC to browser client')
            except websockets.exceptions.ConnectionClosed:
                disconnected.add(client)
        if disconnected:
            self.clients -= disconnected
    async def handle_client(self, websocket):
        """Handle WebSocket client connections (compatible with websockets 3.0+)"""
        client_id = f"{websocket.remote_address[0]}:{websocket.remote_address[1]}"
        client_ip = websocket.remote_address[0]
        try:
            # In websockets 3.0+, the path is available via websocket.request.path
            raw_path = websocket.request.path if hasattr(websocket, 'request') else None
            logger.info(f'Connection from {client_id} with path: {raw_path}')
            
            # Normalize path - handle None, empty, or root path
            path = raw_path.lower().rstrip('/') if raw_path else ''
            
            # Determine client type based on path and source IP
            # - /discord or /discord/ -> Discord bot
            # - /browser or /browser/ -> Browser extension
            # - For unknown paths: localhost = browser, external = Discord bot (Cloudflare tunnel)
            is_localhost = client_ip in ('127.0.0.1', '::1', 'localhost')
            
            if path == '/discord' or path.startswith('/discord'):
                logger.info(f'Discord bot connected from {client_id}')
                await self.handle_discord_bot(websocket)
            elif path == '/browser' or path.startswith('/browser'):
                logger.info(f'Browser client connected from {client_id}')
                await self.handle_browser_client(websocket)
            elif not is_localhost:
                # External connection with unknown/root path - likely Discord bot via Cloudflare tunnel
                logger.info(f'External connection from {client_id} (path: {raw_path}) - treating as Discord bot')
                await self.handle_discord_bot(websocket)
            else:
                # Localhost connection with unknown path - default to browser
                logger.info(f'Localhost connection from {client_id} (path: {raw_path}) - treating as browser')
                await self.handle_browser_client(websocket)
        except websockets.exceptions.ConnectionClosed: logger.info(f'Client disconnected: {client_id}')
        except Exception as e: logger.error(f'Error handling client: {e}')
    async def handle_discord_bot(self, websocket):
        self.discord_bot = websocket  # Store connection for response routing
        try:
            async for message in websocket:
                try:
                    cmd = json.loads(message)
                    logger.info(f'Discord command: {cmd.get("action")}')
                    await self.send_to_ipc(cmd)
                    if self.clients:
                        disconnected = set()
                        for client in self.clients:
                            try: await client.send(json.dumps(cmd))
                            except websockets.exceptions.ConnectionClosed: disconnected.add(client)
                        self.clients -= disconnected
                        await websocket.send(json.dumps({'status': 'command_sent', 'clients': len(self.clients)}))
                    else: await websocket.send(json.dumps({'status': 'command_sent', 'message': 'Command queued to IPC', 'clients': 0}))
                except json.JSONDecodeError: await websocket.send(json.dumps({'error': 'Invalid JSON'}))
        except websockets.exceptions.ConnectionClosed:
            logger.info('Discord bot disconnected')
            self.discord_bot = None
    async def handle_browser_client(self, websocket):
        self.clients.add(websocket); logger.info(f'Browser clients connected: {len(self.clients)}')
        try:
            await websocket.send(json.dumps({'type': 'ready', 'message': 'Extension connected to control server'}))
            async for message in websocket:
                try:
                    data = json.loads(message)
                    if data.get('type') == 'heartbeat': logger.debug(f'Heartbeat from browser client')
                    elif data.get('type') == 'status': logger.debug(f'Status from browser: {data}')
                    elif data.get('id'):
                        logger.debug(f'Browser response: {data}')
                        await self.send_to_ipc(data)
                        # Also send directly to Discord bot if connected to this instance
                        if self.discord_bot:
                            try:
                                await self.discord_bot.send(json.dumps(data))
                                logger.info(f'Routed response directly to Discord bot: {data.get("id")}')
                            except Exception as e:
                                logger.debug(f'Failed to send to Discord bot: {e}')
                except json.JSONDecodeError: pass
        except websockets.exceptions.ConnectionClosed: logger.info('Browser client disconnected')
        finally: self.clients.discard(websocket); logger.info(f'Browser clients remaining: {len(self.clients)}')
ipc_clients = []
async def ipc_server(ready_event):
    if os.path.exists(IPC_SOCKET_PATH): os.remove(IPC_SOCKET_PATH)
    async def handle_ipc(reader, writer):
        ipc_clients.append({'reader': reader, 'writer': writer})
        logger.debug(f'IPC client connected, total: {len(ipc_clients)}')
        try:
            while True:
                line = await reader.readuntil(b'\n')
                if not line: break
                for client in ipc_clients:
                    if client['writer'] != writer:
                        try:
                            client['writer'].write(line)
                            await client['writer'].drain()
                        except:
                            pass
        except asyncio.IncompleteReadError:
            pass
        except Exception as e:
            logger.debug(f'IPC error: {e}')
        finally:
            ipc_clients.remove({'reader': reader, 'writer': writer})
    server = await asyncio.start_unix_server(handle_ipc, IPC_SOCKET_PATH)
    logger.info(f'IPC socket listening at {IPC_SOCKET_PATH}')
    ready_event.set()
    await server.serve_forever()
# Global Plex API handler
plex_api_handler = None

async def setup_http_api():
    """Setup aiohttp HTTP API server for Plex search"""
    global plex_api_handler

    # Initialize Plex API handler
    plex_ip = os.environ.get('IP', '192.168.50.80')
    plex_port = os.environ.get('PORT', '32400')
    plex_token = os.environ.get('PLEX_TOKEN', '')

    plex_api_handler = PlexAPIHandler(plex_ip=plex_ip, plex_port=plex_port, plex_token=plex_token)
    await plex_api_handler.init()

    # Create aiohttp app
    app = web.Application()

    async def health_handler(request):
        """Health check endpoint"""
        return web.json_response({'status': 'ok', 'service': 'plex-discord-server'})

    async def search_handler(request):
        """HTTP handler for Plex search requests"""
        try:
            query = request.rel_url.query.get('query', '').strip()
            if not query:
                return web.json_response({'error': 'Missing query parameter'}, status=400)

            result = await plex_api_handler.search(query)
            if 'error' in result:
                return web.json_response(result, status=500)

            return web.json_response(result)
        except Exception as e:
            logger.error(f'[PlexAPI] Handler error: {e}')
            return web.json_response({'error': str(e)}, status=500)

    async def play_queues_handler(request):
        """HTTP handler for creating play queues"""
        try:
            # Extract all query parameters from the request (already URL-decoded by aiohttp)
            params = dict(request.rel_url.query)

            if not params:
                return web.json_response({'error': 'Missing required parameters'}, status=400)

            logger.info(f'[PlexAPI] Creating play queue with params: {params}')

            # For TV shows, the key ends with /children - remove it for queueing
            # Plex doesn't accept /children keys for playQueues, queue the base show key instead
            if 'key' in params and str(params['key']).endswith('/children'):
                original_key = params['key']
                params['key'] = str(params['key']).replace('/children', '')
                logger.info(f'[PlexAPI] Removed /children from show key: {original_key} -> {params["key"]}')

            # Build the URL with all parameters - params are already decoded, so re-encode them
            # This ensures special characters like / in key paths are properly encoded
            query_parts = []
            for k, v in params.items():
                # URL-encode each parameter value
                encoded_value = quote(str(v), safe='')
                query_parts.append(f'{k}={encoded_value}')

            query_string = '&'.join(query_parts)
            url = f'{plex_api_handler.plex_url}/playQueues?{query_string}&X-Plex-Token={plex_api_handler.plex_token}'

            logger.info(f'[PlexAPI] Play Queue URL: {url}')

            # Use same headers as the server client for consistency
            headers = {
                'X-Plex-Token': plex_api_handler.plex_token,
                'Accept': 'application/json',
            }

            timeout = aiohttp.ClientTimeout(total=60)
            async with plex_api_handler.session.get(url, headers=headers, timeout=timeout) as response:
                if response.status == 200:
                    data = await response.json()
                    logger.info(f'[PlexAPI] Play queue created successfully')
                    return web.json_response(data.get('MediaContainer', {}))
                elif response.status == 403:
                    # 403 Forbidden might mean the token doesn't have permission to create queues
                    # Return partial success so client can attempt direct playback instead
                    logger.warning(f'[PlexAPI] Play queue creation forbidden (403) - token may lack queue creation permission')
                    logger.info(f'[PlexAPI] Returning empty response to allow fallback to direct playback')
                    return web.json_response({'playQueueID': None, 'warning': 'Queue creation not permitted, direct playback will be attempted'}, status=200)
                else:
                    logger.error(f'[PlexAPI] Play queue creation failed: status {response.status}')
                    text = await response.text()
                    logger.error(f'[PlexAPI] Response: {text}')
                    return web.json_response({'error': f'Plex API returned status {response.status}'}, status=500)
        except asyncio.TimeoutError:
            logger.error('[PlexAPI] Play queue timeout')
            return web.json_response({'error': 'Play queue creation timed out'}, status=500)
        except aiohttp.ClientError as e:
            logger.error(f'[PlexAPI] Connection error: {e}')
            return web.json_response({'error': f'Connection error: {e}'}, status=500)
        except Exception as e:
            logger.error(f'[PlexAPI] Handler error: {e}')
            return web.json_response({'error': str(e)}, status=500)

    async def server_identity_handler(request):
        """HTTP handler for getting Plex server identity"""
        try:
            result = await plex_api_handler.get_server_identity()
            if 'error' in result:
                return web.json_response(result, status=500)
            return web.json_response(result)
        except Exception as e:
            logger.error(f'[PlexAPI] Server identity handler error: {e}')
            return web.json_response({'error': str(e)}, status=500)

    app.router.add_get('/health', health_handler)
    app.router.add_get('/search', search_handler)
    app.router.add_get('/playQueues', play_queues_handler)
    app.router.add_get('/identity', server_identity_handler)

    # Cleanup on shutdown
    async def cleanup(app):
        await plex_api_handler.close()

    app.on_cleanup.append(cleanup)
    return app

async def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='0.0.0.0', help='Host to bind to')
    parser.add_argument('--port', type=int, default=8765, help='Port to bind to')
    parser.add_argument('--cert', help='Path to SSL certificate file')
    parser.add_argument('--key', help='Path to SSL key file')
    args = parser.parse_args()
    ssl_context = None
    protocol_scheme = 'ws'
    if args.cert and args.key:
        try:
            # Check if files exist
            if not os.path.exists(args.cert):
                logger.error(f'Certificate file not found: {args.cert}')
                sys.exit(1)
            if not os.path.exists(args.key):
                logger.error(f'Key file not found: {args.key}')
                sys.exit(1)

            # Try to use PROTOCOL_TLS_SERVER first, fall back to PROTOCOL_TLS
            try:
                ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            except AttributeError:
                logger.warning('PROTOCOL_TLS_SERVER not available, using PROTOCOL_TLS')
                ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS)

            ssl_context.load_cert_chain(certfile=args.cert, keyfile=args.key)
            protocol_scheme = 'wss'
            logger.info(f'SSL enabled with cert: {args.cert}')
        except FileNotFoundError as e:
            logger.error(f'Certificate file not found: {e}')
            sys.exit(1)
        except ssl.SSLError as e:
            logger.error(f'SSL error loading certificates: {e}')
            sys.exit(1)
        except Exception as e:
            logger.error(f'Failed to load SSL certificates: {e}')
            sys.exit(1)
    server = PlexDiscordServer(host=args.host, port=args.port, ssl_context=ssl_context)
    http_runner = None

    if args.port == 8765:
        ready_event = asyncio.Event()
        asyncio.create_task(ipc_server(ready_event))
        await ready_event.wait()

        # Setup HTTP API server (only for the main WSS instance on port 8765)
        http_app = await setup_http_api()
        http_runner = web.AppRunner(http_app)
        await http_runner.setup()
        http_site = web.TCPSite(http_runner, '0.0.0.0', 8080)
        await http_site.start()

    await server.connect_ipc()

    logger.info('='*60); logger.info('Plex Discord Control Server'); logger.info('='*60)
    logger.info(f'Starting WebSocket server on {protocol_scheme}://{args.host}:{args.port}')
    logger.info(f'Discord bots connect to: {protocol_scheme}://localhost:{args.port}/discord')
    logger.info(f'Browser extensions connect to: {protocol_scheme}://localhost:{args.port}/browser')
    if http_runner:
        logger.info(f'HTTP API server on http://0.0.0.0:8080')
        logger.info(f'  - Health check: http://localhost:8080/health')
        logger.info(f'  - Plex search: http://localhost:8080/search?query=<query>')
    logger.info('='*60)
    async with websockets.serve(server.handle_client, server.host, server.port, ssl=ssl_context):
        logger.info('Server running... Press Ctrl+C to stop')
        try: await asyncio.Future()
        except KeyboardInterrupt: logger.info('Shutting down...')
        finally:
            if http_runner:
                await http_runner.cleanup()
if __name__ == '__main__': asyncio.run(main())