#!/usr/bin/env python3
import asyncio
import ssl
import websockets
import json
import logging

logging.basicConfig(level=logging.INFO, format='[%(asctime)s] [%(levelname)s] %(message)s')
logger = logging.getLogger(__name__)

async def proxy_websocket(websocket, path):
    """Proxy WebSocket connections from WSS (client) to WSS (backend)"""
    try:
        # Create SSL context for connecting to the backend server (self-signed certificate)
        ssl_context = ssl.create_default_context()
        ssl_context.check_hostname = False
        ssl_context.verify_mode = ssl.CERT_NONE

        # Route to correct backend endpoint based on incoming path
        backend_path = path if path in ['/discord', '/browser'] else '/browser'
        # Use 127.0.0.1 instead of localhost for direct connection to loopback interface
        backend_url = f'wss://127.0.0.1:8765{backend_path}'
        logger.info(f'Routing incoming path {path} to backend: {backend_url}')

        async with websockets.connect(backend_url, ssl=ssl_context) as backend:
            async def forward_from_client():
                try:
                    async for message in websocket:
                        await backend.send(message)
                except websockets.exceptions.ConnectionClosed:
                    pass

            async def forward_from_backend():
                try:
                    async for message in backend:
                        await websocket.send(message)
                except websockets.exceptions.ConnectionClosed:
                    pass

            await asyncio.gather(forward_from_client(), forward_from_backend())
    except Exception as e:
        logger.error(f"Proxy error: {e}")

async def main():
    ssl_context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ssl_context.load_cert_chain(
        certfile='/home/kasm-user/.vnc/self.pem',
        keyfile='/home/kasm-user/.vnc/self.pem'
    )

    async with websockets.serve(proxy_websocket, '0.0.0.0', 8766, ssl=ssl_context):
        logger.info('='*60)
        logger.info('WebSocket SSL Proxy (WSS)')
        logger.info('='*60)
        logger.info('WSS Proxy listening on wss://0.0.0.0:8766')
        logger.info('Routing Discord and Browser connections to backend')
        logger.info('='*60)
        await asyncio.Future()  # run forever

if __name__ == '__main__':
    asyncio.run(main())