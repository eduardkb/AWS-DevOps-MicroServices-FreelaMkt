import os
import requests

_DEFAULT_FALLBACK = "http://169.168.167.166/api"


def _api_url():
    return os.environ.get("API_URL", _DEFAULT_FALLBACK)


def api_get(path, *, token=None, timeout=60):
    url = _api_url().rstrip("/") + "/" + path.lstrip("/")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        resp = requests.get(url, headers=headers, timeout=timeout)
        resp.raise_for_status()
        return resp.json(), 200
    except requests.exceptions.Timeout:
        return {"success": False, "error": f"Request timed out after {timeout} seconds."}, 504
    except requests.exceptions.ConnectionError as e:
        return {"success": False, "error": f"Could not connect to the API: {e}"}, 502
    except requests.exceptions.HTTPError as e:
        return {"success": False, "error": f"API returned an error: {e}"}, 502
    except Exception as e:
        return {"success": False, "error": str(e)}, 500


def api_put(path, *, token=None, json_body=None, timeout=60):
    url = _api_url().rstrip("/") + "/" + path.lstrip("/")
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        resp = requests.put(url, headers=headers, json=json_body, timeout=timeout)
        resp.raise_for_status()
        return resp.json(), 200
    except requests.exceptions.Timeout:
        return {"success": False, "error": f"Request timed out after {timeout} seconds."}, 504
    except requests.exceptions.ConnectionError as e:
        return {"success": False, "error": f"Could not connect to the API: {e}"}, 502
    except requests.exceptions.HTTPError as e:
        try:
            return resp.json(), resp.status_code
        except Exception:
            return {"success": False, "error": f"API returned an error: {e}"}, 502
    except Exception as e:
        return {"success": False, "error": str(e)}, 500
