import hashlib
import aes
from PIL import Image


def genKey(key_string):
    m = hashlib.sha256()
    m.update(key_string.encode())
    hashed256 = m.hexdigest()
    return tuple([int(hashed256[i * 8:i * 8 + 8], 16) for i in range(8)])


def encryptJpg(key, filename):
    jpgFile = Image.open(filename)
    jpgHex = jpgFile.tobytes().hex()

    new_bytes = b''

    for i in range(len(jpgHex) // 32):
        # for i in range(2995, 3000):
        block_bytes = jpgHex[i * 32: i * 32 + 32]
        block = tuple([int(block_bytes[j * 8:j * 8 + 8], 16)
                       for j in range(4)])
        enc_text = aes.aes_encipher_block(key, block)
        # printHex(enc_text)
        enc_bytes = b''.join([t.to_bytes(4, 'big') for t in enc_text])
        new_bytes += enc_bytes
    newImg = Image.frombytes(
        mode=jpgFile.mode, size=jpgFile.size, data=new_bytes)
    newImg.save('encrypted.jpg', format=jpgFile.format)


def decryptJpg(key, filename):
    jpgFile = Image.open(filename)
    jpgHex = jpgFile.tobytes().hex()
    new_bytes = b''

    for i in range(len(jpgHex) // 32):
        # for i in range(2995, 3000):
        block_bytes = jpgHex[i * 32: i * 32 + 32]
        block = tuple([int(block_bytes[j * 8:j * 8 + 8], 16)
                       for j in range(4)])
        enc_text = aes.aes_decipher_block(key, block)
        # printHex(enc_text)
        enc_bytes = b''.join([t.to_bytes(4, 'big') for t in enc_text])
        new_bytes += enc_bytes
    newImg = Image.frombytes(
        mode=jpgFile.mode, size=jpgFile.size, data=new_bytes)
    newImg.save('decrypted.jpg', format=jpgFile.format)


def printHex(tupled_text):
    print([hex(t) for t in tupled_text])


def testReadWrite():
    f = Image.open('Tux.jpg')
    hexed = f.tobytes().hex()
    # print(hexed)
    new_bytes = b''
    for i in range(len(hexed) // 32):
        hexed_this = hexed[i * 32: i * 32 + 32]
        hexed_tuple = tuple([int(hexed_this[j * 8:j * 8 + 8], 16)
                             for j in range(4)])
        bytes_strs = [t.to_bytes(4, 'big') for t in hexed_tuple]
        bytes_str = b''.join(bytes_strs)
        new_bytes += bytes_str
    # print(new_bytes)
    f_out = Image.frombytes(mode=f.mode, size=f.size, data=new_bytes)
    f_out.save('test.jpg', format=f.format)

    f2 = Image.open('test.jpg')
    print(f2.tobytes().hex())


if __name__ == '__main__':
    key = genKey('NTUEE')

    fileToEncrypt = 'Tux.jpg'
    encryptJpg(key, fileToEncrypt)

    fileToDecrypt = 'encrypted.jpg'
    decryptJpg(key, fileToDecrypt)
