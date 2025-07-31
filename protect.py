from argon2.low_level import hash_secret_raw, Type
from Crypto.Cipher import AES
from Crypto.Random import get_random_bytes
import base64

# Constants
SALT_SIZE = 16
NONCE_SIZE = 12
KEY_SIZE = 32  # AES-256
ARGON2_TIME_COST = 2
ARGON2_MEMORY_COST = 65536  # in KB (64 MB)
ARGON2_PARALLELISM = 2

# --- ENCRYPT ---


def encrypt_string(password: str, plaintext: str) -> str:
    salt = get_random_bytes(SALT_SIZE)
    nonce = get_random_bytes(NONCE_SIZE)

    key = hash_secret_raw(
        secret=password.encode("utf-8"),
        salt=salt,
        time_cost=ARGON2_TIME_COST,
        memory_cost=ARGON2_MEMORY_COST,
        parallelism=ARGON2_PARALLELISM,
        hash_len=KEY_SIZE,
        type=Type.ID
    )

    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    ciphertext, tag = cipher.encrypt_and_digest(plaintext.encode("utf-8"))

    # Combine salt + nonce + tag + ciphertext
    encrypted_blob = salt + nonce + tag + ciphertext
    return base64.b64encode(encrypted_blob).decode("utf-8")

# --- DECRYPT ---


def decrypt_string(password: str, encrypted_b64: str) -> str:
    data = base64.b64decode(encrypted_b64.encode("utf-8"))

    salt = data[:SALT_SIZE]
    nonce = data[SALT_SIZE:SALT_SIZE+NONCE_SIZE]
    tag = data[SALT_SIZE+NONCE_SIZE:SALT_SIZE+NONCE_SIZE+16]
    ciphertext = data[SALT_SIZE+NONCE_SIZE+16:]

    key = hash_secret_raw(
        secret=password.encode("utf-8"),
        salt=salt,
        time_cost=ARGON2_TIME_COST,
        memory_cost=ARGON2_MEMORY_COST,
        parallelism=ARGON2_PARALLELISM,
        hash_len=KEY_SIZE,
        type=Type.ID
    )

    cipher = AES.new(key, AES.MODE_GCM, nonce=nonce)
    plaintext = cipher.decrypt_and_verify(ciphertext, tag)

    return plaintext.decode("utf-8")
