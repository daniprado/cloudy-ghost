import requests
import jwt
import logging
import json
from datetime import datetime as date
from os import environ as osenv
from traceback import TracebackException

import azure.functions as func
from opencensus.ext.azure.log_exporter import AzureLogHandler

AI_CONN = f"InstrumentationKey={osenv['APPINSIGHTS_INSTRUMENTATIONKEY']}"
GHOST_KEY = osenv['GHOST_API_KEY']
GHOST_BASE_URL = osenv['GHOST_BASE_URL']

# Set up logging
logger = logging.getLogger('Gitsino')
logger.setLevel(logging.INFO)
logger.addHandler(AzureLogHandler(connection_string=AI_CONN))

# Get auth token from Ghost App
id, secret = GHOST_KEY.split(':')
iat = int(date.now().timestamp())
header = {'alg': 'HS256', 'typ': 'JWT', 'kid': id}
payload = {
    'iat': iat,
    'exp': iat + 5 * 60,
    'aud': '/v3/admin/'
}
token = jwt.encode(payload,
                   bytes.fromhex(secret),
                   algorithm='HS256',
                   headers=header)


def get_all_post_ids() -> list:
    url = f"{GHOST_BASE_URL}/api/v3/admin/posts?limit=all&fields=id"
    headers = {'Authorization': 'Ghost {}'.format(token.decode())}
    r = requests.get(url, headers=headers)
    r.raise_for_status()
    return [post.get('id') for post in r.json()]


def delete_post(id: str):
    url = f"{GHOST_BASE_URL}/api/v3/admin/posts/{id}"
    headers = {'Authorization': 'Ghost {}'.format(token.decode())}
    r = requests.delete(url, headers=headers)
    r.raise_for_status()


def main(req: func.HttpRequest) -> func.HttpResponse:

    resp_body = {}
    resp_code = -1
    try:
        logging.info("Cleaning all posts...")
        ids = get_all_post_ids()
        for id in ids:
            delete_post(id)
        logging.info("Posts deleted!")
        resp_body = {'ids': ids}
        resp_code = 204

    except Exception as e:
        tb = TracebackException.from_exception(e)
        stack = ''.join(tb.format())
        logging.error(f"Something failed! {stack}")
        resp_body = {'error': stack}
        resp_code = 500

    finally:
        return func.HttpResponse(json.dumps(resp_body),
                                 status_code=resp_code,
                                 mimetype="application/json")

