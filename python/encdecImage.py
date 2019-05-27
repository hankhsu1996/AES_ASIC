import hashlib
import io
import aes
from PIL import Image


def genKey(key_string):
    m = hashlib.sha256()
    m.update(key_string.encode())
    hashed256 = m.hexdigest()
    return tuple([int(hashed256[i * 8:i * 8 + 8], 16) for i in range(8)])


def encryptTxtECB(key, txtInFilename, txtOutFilename):
    with open(txtInFilename, 'r') as f:
        size_str = f.readline()
        mode_str = f.readline()
        data_str = f.readline()
        data_hex = data_str.split()[-1]

    new_data_hex = ''
    for i in range(len(data_hex) // 32):
        block_hex = data_hex[i * 32: i * 32 + 32]
        block = tuple([int(block_hex[j * 8:j * 8 + 8], 16)
                       for j in range(4)])
        enc_text = aes.aes_encipher_block(key, block)
        enc_hex = ''.join(['{:08x}'.format(t) for t in enc_text])
        new_data_hex += enc_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def decryptTxtECB(key, txtInFilename, txtOutFilename):
    with open(txtInFilename, 'r') as f:
        size_str = f.readline()
        mode_str = f.readline()
        data_str = f.readline()
        data_hex = data_str.split()[-1]

    new_data_hex = ''
    for i in range(len(data_hex) // 32):
        block_hex = data_hex[i * 32: i * 32 + 32]
        block = tuple([int(block_hex[j * 8:j * 8 + 8], 16)
                       for j in range(4)])
        enc_text = aes.aes_decipher_block(key, block)
        enc_hex = ''.join(['{:08x}'.format(t) for t in enc_text])
        new_data_hex += enc_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def writeToText(jpgFilename, txtFilename):
    img = Image.open(jpgFilename)
    with open(txtFilename, 'w') as f:
        f.write('size: ')
        f.write(str(img.size))
        f.write('\n')
        f.write('mode: ')
        f.write(img.mode)
        f.write('\n')
        f.write('data: ')
        f.write(img.tobytes().hex())
        f.write('\n')


def writeToJpg(txtFilename, jpgFilename):
    with open(txtFilename, 'r') as f:
        size = eval(f.readline().split('size: ')[1].strip())
        mode = f.readline().split('mode: ')[1].strip()
        hex_data = f.readline().split()[1].strip()
    img = Image.frombytes(size=size, mode=mode, data=bytes.fromhex(hex_data))
    img.save(jpgFilename, format='jpeg')


if __name__ == '__main__':
    writeToText('Tux.jpg', 'raw_data.txt')
    writeToJpg('raw_data.txt', 'test.jpg')

    key = genKey('NTUEE')

    encryptTxtECB(key, 'raw_data.txt', 'encrypted.txt')
    writeToJpg('encrypted.txt', 'encrypted.jpg')

    decryptTxtECB(key, 'encrypted.txt', 'decrypted.txt')
    writeToJpg('decrypted.txt', 'decrypted.jpg')
