"""Fetch only the official Windows release member using HTTPS ZIP range reads."""
import io
import pathlib
import urllib.request
import zipfile

URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
SIZE = 1281349702
DEST = pathlib.Path(__file__).resolve().parents[1] / 'build' / 'templates'

class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.pos = 0
        self.requests = 0

    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos

    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else SIZE + offset
        return self.pos

    def read(self, n=-1):
        if n < 0: n = SIZE-self.pos
        n = min(n, SIZE-self.pos)
        if n <= 0: return b''
        if n > 96*1024*1024: raise RuntimeError('Unexpectedly large ZIP read')
        start = self.pos
        req = urllib.request.Request(URL, headers={'Range':f'bytes={start}-{start+n-1}', 'User-Agent':'Weaver-build/0.5'})
        with urllib.request.urlopen(req, timeout=90) as response:
            if response.status != 206:
                raise RuntimeError(f'Host does not support safe partial download: {response.status}')
            expected = f'bytes {start}-{start+n-1}/'
            if not response.headers.get('Content-Range','').startswith(expected):
                raise RuntimeError('Content range mismatch')
            data=response.read(n+1)
        if len(data)!=n: raise RuntimeError('Truncated range')
        self.pos+=n
        self.requests+=1
        return data

DEST.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    members=[x for x in archive.infolist() if x.filename.endswith('/windows_release_x86_64.exe')]
    if len(members)!=1: raise RuntimeError('Expected exactly one Windows release template')
    member=members[0]
    print('Official template:',member.filename,'compressed bytes:',member.compress_size,flush=True)
    target=DEST/'windows_release_x86_64.exe'
    if target.exists(): raise RuntimeError('Target exists; verify it rather than overwriting')
    # read() also verifies the member CRC before returning.
    content=archive.read(member)
    if len(content)!=member.file_size or content[:2]!=b'MZ': raise RuntimeError('Invalid executable')
    target.write_bytes(content)
    print('TEMPLATE_READY',target,'bytes=',len(content), 'CRC verified',flush=True)
