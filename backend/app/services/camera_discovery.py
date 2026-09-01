import socket
import time
import uuid
import ipaddress
from urllib.parse import urlsplit
from xml.etree import ElementTree

from onvif import ONVIFCamera
from zeep.transports import Transport


DISCOVERY_ADDRESS = ("239.255.255.250", 3702)
ONVIF_CONNECT_TIMEOUT_SECONDS = 3
ONVIF_OPERATION_TIMEOUT_SECONDS = 5


class ONVIFConnectionError(ValueError):
    """The camera's ONVIF service could not be reached quickly."""


def discover_onvif_cameras(timeout_seconds: float = 3.0) -> list[dict]:
    message_id = uuid.uuid4()
    probe = f'''<?xml version="1.0" encoding="UTF-8"?>
<e:Envelope xmlns:e="http://www.w3.org/2003/05/soap-envelope"
 xmlns:w="http://schemas.xmlsoap.org/ws/2004/08/addressing"
 xmlns:d="http://schemas.xmlsoap.org/ws/2005/04/discovery"
 xmlns:dn="http://www.onvif.org/ver10/network/wsdl">
 <e:Header><w:MessageID>uuid:{message_id}</w:MessageID>
 <w:To e:mustUnderstand="true">urn:schemas-xmlsoap-org:ws:2005:04:discovery</w:To>
 <w:Action e:mustUnderstand="true">http://schemas.xmlsoap.org/ws/2005/04/discovery/Probe</w:Action></e:Header>
 <e:Body><d:Probe><d:Types>dn:NetworkVideoTransmitter</d:Types></d:Probe></e:Body>
</e:Envelope>'''.encode("utf-8")

    results: dict[str, dict] = {}
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.IPPROTO_IP, socket.IP_MULTICAST_TTL, 2)
    sock.settimeout(0.35)
    try:
        sock.sendto(probe, DISCOVERY_ADDRESS)
        deadline = time.monotonic() + timeout_seconds
        while time.monotonic() < deadline:
            try:
                payload, address = sock.recvfrom(65535)
            except socket.timeout:
                continue
            try:
                root = ElementTree.fromstring(payload)
            except ElementTree.ParseError:
                continue
            xaddrs = _first_text(root, "XAddrs").split()
            scopes = _first_text(root, "Scopes")
            for service_url in xaddrs:
                parsed = urlsplit(service_url)
                if parsed.hostname:
                    results[service_url] = {
                        "id": service_url,
                        "name": _camera_name(scopes, parsed.hostname),
                        "host": parsed.hostname,
                        "service_url": service_url,
                    }
            if not xaddrs and address[0]:
                service_url = f"http://{address[0]}/onvif/device_service"
                results[service_url] = {
                    "id": service_url,
                    "name": f"ONVIF Camera ({address[0]})",
                    "host": address[0],
                    "service_url": service_url,
                }
    finally:
        sock.close()
    return sorted(results.values(), key=lambda item: (item["name"], item["host"]))


def resolve_onvif_stream(service_url: str, username: str, password: str) -> str:
    parsed = urlsplit(service_url)
    if parsed.scheme not in {"http", "https"} or not parsed.hostname:
        raise ValueError("Invalid ONVIF service URL.")
    _ensure_local_camera_host(parsed.hostname)
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        connection = socket.create_connection(
            (parsed.hostname, port),
            timeout=ONVIF_CONNECT_TIMEOUT_SECONDS,
        )
        connection.close()
    except (OSError, TimeoutError) as exc:
        raise ONVIFConnectionError(
            f"ONVIF is not reachable on port {port}."
        ) from exc

    transport = Transport(
        timeout=ONVIF_CONNECT_TIMEOUT_SECONDS,
        operation_timeout=ONVIF_OPERATION_TIMEOUT_SECONDS,
    )
    camera = ONVIFCamera(
        parsed.hostname,
        port,
        username,
        password,
        transport=transport,
    )
    media = camera.create_media_service()
    profiles = media.GetProfiles()
    if not profiles:
        raise ValueError("The camera did not provide a media profile.")
    request = media.create_type("GetStreamUri")
    request.StreamSetup = {"Stream": "RTP-Unicast", "Transport": {"Protocol": "RTSP"}}
    request.ProfileToken = profiles[0].token
    response = media.GetStreamUri(request)
    uri = str(response.Uri).strip()
    if not uri:
        raise ValueError("The camera did not provide a stream URL.")
    return uri


def _ensure_local_camera_host(host: str) -> None:
    try:
        addresses = {
            item[4][0]
            for item in socket.getaddrinfo(host, None, type=socket.SOCK_STREAM)
        }
    except socket.gaierror as exc:
        raise ValueError("Camera host could not be resolved.") from exc
    if not addresses:
        raise ValueError("Camera host could not be resolved.")
    for address in addresses:
        value = ipaddress.ip_address(address)
        if value.is_loopback or value.is_multicast or value.is_unspecified or value.is_reserved:
            raise ValueError("Invalid local camera address.")
        if value.is_private or value.is_link_local:
            continue
        raise ValueError("ONVIF cameras must be on the server's local network.")


def _first_text(root: ElementTree.Element, local_name: str) -> str:
    for element in root.iter():
        if element.tag.rsplit("}", 1)[-1] == local_name:
            return (element.text or "").strip()
    return ""


def _camera_name(scopes: str, fallback: str) -> str:
    for scope in scopes.split():
        marker = "/name/"
        if marker in scope:
            value = scope.split(marker, 1)[1].replace("%20", " ").strip()
            if value:
                return value
    return f"ONVIF Camera ({fallback})"
