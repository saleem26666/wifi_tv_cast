from datetime import datetime, timedelta, timezone
from pathlib import Path
import ipaddress

from cryptography import x509
from cryptography.x509.oid import NameOID
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
subject = issuer = x509.Name([
    x509.NameAttribute(NameOID.COMMON_NAME, 'TV-WiFi-Cast'),
    x509.NameAttribute(NameOID.ORGANIZATION_NAME, 'Personal'),
])
alt = x509.SubjectAlternativeName([
    x509.DNSName('localhost'),
    x509.DNSName('tv-wifi-cast.local'),
    x509.IPAddress(ipaddress.IPv4Address('127.0.0.1')),
])
cert = (
    x509.CertificateBuilder()
    .subject_name(subject)
    .issuer_name(issuer)
    .public_key(key.public_key())
    .serial_number(x509.random_serial_number())
    .not_valid_before(datetime.now(timezone.utc) - timedelta(days=1))
    .not_valid_after(datetime.now(timezone.utc) + timedelta(days=3650))
    .add_extension(alt, critical=False)
    .add_extension(x509.BasicConstraints(ca=True, path_length=None), critical=True)
    .sign(key, hashes.SHA256())
)
out = Path(__file__).resolve().parents[1] / 'assets' / 'certs'
out.mkdir(parents=True, exist_ok=True)
(out / 'cert.pem').write_bytes(cert.public_bytes(serialization.Encoding.PEM))
(out / 'key.pem').write_bytes(
    key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.TraditionalOpenSSL,
        encryption_algorithm=serialization.NoEncryption(),
    )
)
print('wrote', out / 'cert.pem')
print('wrote', out / 'key.pem')
