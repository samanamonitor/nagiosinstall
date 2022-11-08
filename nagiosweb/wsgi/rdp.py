from urllib.parse import parse_qs

def application(environ, start_response):
    query = parse_qs(environ['QUERY_STRING'])
    host = query.get('host', [])

    if len(host) > 0:
        status = '200 OK'
        d = """
screen mode id:i:1
use multimon:i:0
desktopwidth:i:1440
desktopheight:i:873
session bpp:i:32
winposstr:s:0,1,0,0,1440,833
compression:i:1
keyboardhook:i:2
audiocapturemode:i:0
videoplaybackmode:i:1
connection type:i:7
networkautodetect:i:1
bandwidthautodetect:i:1
displayconnectionbar:i:1
enableworkspacereconnect:i:0
disable wallpaper:i:0
allow font smoothing:i:0
allow desktop composition:i:0
disable full window drag:i:1
disable menu anims:i:1
disable themes:i:0
disable cursor setting:i:0
bitmapcachepersistenable:i:1
full address:s:%s

audiomode:i:0
redirectprinters:i:1
redirectcomports:i:0
redirectsmartcards:i:1
redirectclipboard:i:1
redirectposdevices:i:0
autoreconnection enabled:i:1
authentication level:i:2
prompt for credentials:i:0
negotiate security layer:i:1
remoteapplicationmode:i:0
alternate shell:s:
shell working directory:s:
gatewayhostname:s:
gatewayusagemethod:i:4
gatewaycredentialssource:i:4
gatewayprofileusagemethod:i:0
promptcredentialonce:i:0
gatewaybrokeringtype:i:0
use redirection server name:i:0
rdgiskdcproxy:i:0
kdcproxyname:s:
""" % host[0]
        response_headers = [('Content-type', 'application/x-rdp'),
                            ('Content-Length', str(len(d))),
                            ('Content-Disposition', 'attachment; filename=Application.rdp')]
    else:
        response_headers = []
        status = '501 Invalid Query'
        d = 'Invalid Query'

    start_response(status, response_headers)

    return [ d.encode('ascii') ]
