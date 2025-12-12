#!/usr/bin/env python3
"""Cli tool to assist gather parse client id's for a given Plex user."""

import base64
import datetime
import hashlib
import json
import os
from collections import OrderedDict
from getpass import getpass
from pathlib import Path

import click
import http.client
import keyring
import xmltodict

PLEX_HOSTNAME = 'plex.tv'
PLEX_SIGN_IN_URI = '/users/sign_in.json'
PLEX_API_RESOURCE_URI = '/api/resources.xml'
CREDS_FILE = os.path.expanduser('~/.plex_credentials.json')


class PlexHelper:
    """Plex Helper class."""

    def __init__(self, hostname=PLEX_HOSTNAME, sign_in_uri=PLEX_SIGN_IN_URI, resource_uri=PLEX_API_RESOURCE_URI, version=None, verbose=False):
        """Init the helper class."""
        self.hostname = hostname
        self.sign_in_uri = sign_in_uri
        self.resource_uri = resource_uri
        self.version = version if version else '0.001'
        self.verbose = verbose
        self.client_name = 'Client Name: Gathering Auth Token'
        self.client_version = f'Client Version: {self.version}'
        self.client_id = hashlib.sha512(f'{self.client_name} {self.client_version}'.encode()).hexdigest()
        self.auth_token = self.get_auth_token()
        self.filtered_keys = ['@product', '@platform', '@clientIdentifier']
        self.date_specs = ['@createdAt', '@lastSeenAt']

    def _save_credentials_to_file(self, username, password):
        """Save credentials to file as fallback when keyring unavailable."""
        creds = {'username': username, 'password': password}
        try:
            with open(CREDS_FILE, 'w') as f:
                json.dump(creds, f)
            os.chmod(CREDS_FILE, 0o600)  # Restrict to user only
        except Exception as e:
            print(f'Warning: Could not save credentials to file: {e}')

    def _load_credentials_from_file(self):
        """Load credentials from file as fallback when keyring unavailable."""
        try:
            if os.path.exists(CREDS_FILE):
                with open(CREDS_FILE, 'r') as f:
                    creds = json.load(f)
                    return creds.get('username'), creds.get('password')
        except Exception as e:
            print(f'Warning: Could not load credentials from file: {e}')
        return None, None

    def set_plex_credentials(self):
        """Set your Plex credentials in your keychain or file.

        :return: str plex_username, str plex_password
        """
        plex_username = getpass('Please enter your Plex username: ')
        plex_password = getpass('Please enter your Plex password: ')

        # Try keyring first
        try:
            keyring.set_password('plex', 'plex_username', plex_username)
            keyring.set_password('plex', plex_username, plex_password)
        except Exception:
            # Fall back to file storage
            self._save_credentials_to_file(plex_username, plex_password)

        return plex_username, plex_password

    def get_2fa_code(self):
        """Get 2FA code from user.

        :return: str, 2fa_code
        """
        return input('Please enter your 2FA code: ')

    def get_plex_credentials(self):
        """Gather Plex credentials if stored in keyring/file, otherwise prompt for them.

        :return: str plex_username, str plex_password
        """
        plex_username = None
        plex_password = None

        # Try keyring first
        try:
            plex_username = keyring.get_password('plex', 'plex_username')
            if plex_username:
                plex_password = keyring.get_password('plex', plex_username)
        except Exception:
            # Fall back to file
            plex_username, plex_password = self._load_credentials_from_file()

        if not plex_username:
            plex_username, plex_password = self.set_plex_credentials()

        return plex_username, plex_password

    def get_auth_token(self):
        """Get Plex auth token.

        :return: str, auth_token
        """
        username, password = self.get_plex_credentials()
        base64string = base64.b64encode(f'{username}:{password}'.encode())
        headers = {'Authorization': f'Basic {base64string.decode("ascii")}',
                   'X-Plex-Client-Identifier': self.client_id,
                   'X-Plex-Product': self.client_name,
                   'X-Plex-Version': self.client_version}

        conn = http.client.HTTPSConnection(self.hostname)
        conn.request('POST', self.sign_in_uri, '', headers)
        response = conn.getresponse()
        data = json.loads(response.read().decode())

        if self.verbose:
            print(f'HTTP request: {self.hostname}{self.sign_in_uri}')
            print(f'status: {response.status}, reason: {response.reason}')
            print(f'Response data: {data}')

        # Handle 2FA requirement
        if response.status == 401:
            print('Authentication failed. This may be due to 2FA being enabled.')
            print('Please enter your 2FA code to retry.')
            twofa_code = self.get_2fa_code()
            headers['X-Plex-OTP'] = twofa_code

            conn = http.client.HTTPSConnection(self.hostname)
            conn.request('POST', self.sign_in_uri, '', headers)
            response = conn.getresponse()
            data = json.loads(response.read().decode())

            if self.verbose:
                print(f'Retrying with 2FA code...')
                print(f'status: {response.status}, reason: {response.reason}')
                print(f'Response data: {data}')

        if response.status != 201:
            raise Exception(f'Authentication failed. Status: {response.status}, Response: {data}')

        if 'user' not in data:
            raise Exception(f'Unexpected response format. Expected "user" key in response: {data}')

        auth_token = data['user']['authentication_token']
        if self.verbose:
            print(f'Auth-Token: {auth_token}')
        conn.close()
        return auth_token

    def get_api_resouces(self):
        """Get the Plex api resources per given token.

        :return: list, device resource list
        """
        conn = http.client.HTTPSConnection(self.hostname)
        conn.request('GET', f'{self.resource_uri}?auth_token={self.auth_token}')
        response = conn.getresponse()
        xml_data = response.read().decode()
        xml_dict = xmltodict.parse(xml_data)
        json_dump = json.dumps(xml_dict)
        conn.close()
        return json.loads(json_dump)['MediaContainer']['Device']

    def get_active_sessions(self, server_ip, server_port):
        """Get active player sessions from Plex server.

        Try multiple endpoints to find active sessions.

        :param server_ip: IP address of Plex server
        :param server_port: Port of Plex server
        :return: dict, full media container with all session data
        """
        endpoints_to_try = [
            '/status/sessions',
            '/library/sections',
            '/playQueues',
            '/'
        ]

        for endpoint in endpoints_to_try:
            try:
                conn = http.client.HTTPConnection(server_ip, server_port)
                url = f'{endpoint}?X-Plex-Token={self.auth_token}'

                if self.verbose:
                    print(f'\nTrying endpoint: {endpoint}')

                conn.request('GET', url)
                response = conn.getresponse()
                xml_data = response.read().decode()

                if self.verbose:
                    print(f'Status: {response.status}')

                if response.status == 200:
                    if self.verbose:
                        print(f'Success with {endpoint}!')
                        print(f'Response body (first 400 chars):')
                        print(xml_data[:400])
                        print()

                    try:
                        xml_dict = xmltodict.parse(xml_data)
                        json_dump = json.dumps(xml_dict)
                        conn.close()
                        media_container = json.loads(json_dump).get('MediaContainer', {})
                        return media_container
                    except Exception as parse_error:
                        if self.verbose:
                            print(f'Error parsing response: {parse_error}')
                        conn.close()
                        continue
                else:
                    if self.verbose:
                        print(f'Got status {response.status}')
                    conn.close()
            except Exception as e:
                if self.verbose:
                    print(f'Error: {e}')
                continue

        return {}

    def get_filtered_resources(self):
        """Filter out the resources returned from api.

        :return: dict
        """
        resource_list = self.get_api_resouces()
        device_dict = {}
        for device in resource_list:
            device_dict[device.get('@name')] = {}
            for spec, v in device.items():
                if spec in self.filtered_keys:
                    device_dict[device.get('@name')][str(spec)] = str(v)
                if spec in self.date_specs:
                    parsed_date = datetime.datetime.fromtimestamp(int(v)).strftime('%Y-%m-%d %H:%M:%S')
                    device_dict[device.get('@name')][str(spec)] = str(parsed_date)
        return device_dict


@click.command()
@click.option('-v', '--verbose', is_flag=True)
def main(verbose):
    """Main entry point for python Plex client identifier.

    :param: verbose: bool, print more verbose details
    """
    plex_helper = PlexHelper(verbose=verbose)

    # Print credentials for .env file
    print('\n' + '='*60)
    print('Add these to your .env file:')
    print('='*60)
    print(f'MACHINE_IDENTIFIER={plex_helper.client_id}')
    print(f'AUTH_TOKEN={plex_helper.auth_token}')
    print('='*60 + '\n')

    devices = plex_helper.get_filtered_resources()
    print('Connected Devices:')
    print('-' * 60)
    for name, device_details in devices.items():
        print(f'Device name: {name}')
        for k, v in device_details.items():
            print(f'\t{k.split("@")[1]}: {v}')
        print()

    # Try to get active sessions from each server
    print('\nActive Player Sessions:')
    print('-' * 60)

    # List of IPs to try
    ips_to_try = ['192.168.50.63', '192.168.50.80', '127.0.0.1', 'localhost']

    sessions_found = False
    for server_ip in ips_to_try:
        try:
            if verbose:
                print(f'Trying to get sessions from {server_ip}:32400...')

            media_container = plex_helper.get_active_sessions(server_ip, 32400)
            if media_container and media_container.get('Video'):
                sessions_found = True
                sessions = media_container.get('Video', [])
                if not isinstance(sessions, list):
                    sessions = [sessions]

                for session in sessions:
                    # Extract player and media info
                    player = session.get('Player', {})
                    user = session.get('User', {})
                    media = session.get('Media', {})

                    # Try multiple possible client ID attribute names
                    client_id = (player.get('@clientIdentifier') or
                                player.get('@machineIdentifier') or
                                'Unknown')
                    player_name = player.get('@title', 'Unknown')
                    media_title = session.get('@title', 'Unknown')  # Use session title if media not available
                    user_name = user.get('@title', 'Unknown')

                    print(f'Active Player: {player_name}')
                    print(f'\tclientIdentifier/machineIdentifier: {client_id}')
                    print(f'\tUser: {user_name}')
                    print(f'\tNow Playing: {media_title}')
                    print()
                break
        except Exception as e:
            if verbose:
                print(f'Error getting sessions from {server_ip}: {e}')

    if not sessions_found:
        print('No active player sessions found.')
        print('Make sure a Plex player is actively playing content.')
        print()

if __name__ == "__main__":
    main()
