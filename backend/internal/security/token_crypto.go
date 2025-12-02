package security

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"crypto/sha256"
	"encoding/base64"
	"encoding/hex"
	"errors"
	"io"
)

// DeriveKey normalizes arbitrary secrets into a 32-byte AES key.
func DeriveKey(secret string) []byte {
	sum := sha256.Sum256([]byte(secret))
	key := make([]byte, len(sum))
	copy(key, sum[:])
	return key
}

// EncryptToken encrypts the token using AES-GCM and returns nonce||ciphertext.
func EncryptToken(key []byte, plaintext string) ([]byte, error) {
	if len(key) == 0 {
		return nil, errors.New("encryption key missing")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	nonce := make([]byte, gcm.NonceSize())
	if _, err = io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, err
	}
	ciphertext := gcm.Seal(nil, nonce, []byte(plaintext), nil)
	return append(nonce, ciphertext...), nil
}

// DecryptToken decrypts the blob created by EncryptToken.
func DecryptToken(key []byte, payload []byte) (string, error) {
	if len(key) == 0 {
		return "", errors.New("encryption key missing")
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return "", err
	}
	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return "", err
	}
	if len(payload) < gcm.NonceSize() {
		return "", errors.New("ciphertext too short")
	}
	nonce := payload[:gcm.NonceSize()]
	ciphertext := payload[gcm.NonceSize():]
	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		return "", err
	}
	return string(plaintext), nil
}

// HashToken returns a deterministic hash for lookup.
func HashToken(token string) string {
	sum := sha256.Sum256([]byte(token))
	return hex.EncodeToString(sum[:])
}

// GenerateToken returns a base64url-encoded random token.
func GenerateToken(bytesLen int) (string, error) {
	if bytesLen <= 0 {
		bytesLen = 32
	}
	buf := make([]byte, bytesLen)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	return base64.RawURLEncoding.EncodeToString(buf), nil
}
