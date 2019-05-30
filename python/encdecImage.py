import hashlib
import io
import aes
from PIL import Image

VERBOSE = True


def genKey128(key_string):
    if VERBOSE:
        print('genKey128')
    m = hashlib.sha256()
    m.update(key_string.encode())
    hashed256 = m.hexdigest()
    return tuple([int(hashed256[i * 8:i * 8 + 8], 16) for i in range(4)])


def genKey256(key_string):
    if VERBOSE:
        print('genKey256')
    m = hashlib.sha256()
    m.update(key_string.encode())
    hashed256 = m.hexdigest()
    return tuple([int(hashed256[i * 8:i * 8 + 8], 16) for i in range(8)])


def encryptTxtECB(key, txtInFilename, txtOutFilename):
    if VERBOSE:
        print('encryptTxtECB')
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
        enc_tuple = aes.aes_encipher_block(key, block)
        enc_hex = ''.join(['{:08x}'.format(t) for t in enc_tuple])
        new_data_hex += enc_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def encryptTxtCBC(key, IV, txtInFilename, txtOutFilename):
    if VERBOSE:
        print('encryptTxtCBC')
    IV_tmp = IV
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
        block = tuple([block[i] ^ IV_tmp[i] for i in range(4)])
        enc_tuple = aes.aes_encipher_block(key, block)
        IV_tmp = enc_tuple
        enc_hex = ''.join(['{:08x}'.format(t) for t in enc_tuple])
        new_data_hex += enc_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def decryptTxtECB(key, txtInFilename, txtOutFilename):
    if VERBOSE:
        print('decryptTxtECB')
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
        dec_tuple = aes.aes_decipher_block(key, block)
        dec_hex = ''.join(['{:08x}'.format(t) for t in dec_tuple])
        new_data_hex += dec_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def decryptTxtCBC(key, IV, txtInFilename, txtOutFilename):
    if VERBOSE:
        print('decryptTxtCBC')
    IV_next = IV
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
        IV_this = IV_next
        IV_next = block
        dec_tuple = aes.aes_decipher_block(key, block)
        dec_tuple = tuple([dec_tuple[i] ^ IV_this[i] for i in range(4)])
        dec_hex = ''.join(['{:08x}'.format(t) for t in dec_tuple])
        new_data_hex += dec_hex

    with open(txtOutFilename, 'w') as fw:
        fw.write(size_str)
        fw.write(mode_str)
        fw.write('data: ')
        fw.write(new_data_hex)
        fw.write('\n')


def writeToText(jpgFilename, txtFilename):
    if VERBOSE:
        print('writeToText')
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
    if VERBOSE:
        print('writeToJpg')
    with open(txtFilename, 'r') as f:
        size = eval(f.readline().split('size: ')[1].strip())
        mode = f.readline().split('mode: ')[1].strip()
        hex_data = f.readline().split()[1].strip()
    img = Image.frombytes(size=size, mode=mode, data=bytes.fromhex(hex_data))
    img.save(jpgFilename, format='jpeg')


if __name__ == '__main__':
    writeToText('DAT/Bled.jpg', 'DAT/raw_data.txt')

    key = genKey256('NTUEE')
    IV = genKey128('Integrated Circuits Design Laboratory')

    encryptTxtCBC(key, IV, 'DAT/raw_data.txt', 'DAT/encrypted.txt')
    writeToJpg('DAT/encrypted.txt', 'DAT/encrypted.jpg')

    decryptTxtCBC(key, IV, 'DAT/encrypted.txt', 'DAT/decrypted.txt')
    writeToJpg('DAT/decrypted.txt', 'DAT/decrypted.jpg')
