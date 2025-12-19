#!/bin/bash
# Script tạo nhiều user cho load testing
# Mỗi user có rate limit 10 req/min, nên cần nhiều user để test high RPS

API_BASE="${API_BASE:-http://localhost:8080}"
NUM_USERS="${NUM_USERS:-20}"
WALLET_AMOUNT="${WALLET_AMOUNT:-2000000}"

echo " Tạo $NUM_USERS user cho load testing..."
echo "API: $API_BASE"
echo ""

TOKENS=""

for i in $(seq 1 $NUM_USERS); do
  EMAIL="loadtest.user$i@example.com"
  PASSWORD="loadtest123"
  
  # Đăng ký user (ignore nếu đã tồn tại)
  curl -s -X POST "$API_BASE/auth/register" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"Load Test User $i\",\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\",\"phone\":\"090000$(printf '%04d' $i)\"}" > /dev/null 2>&1
  
  # Đăng nhập lấy token
  TOKEN=$(curl -s -X POST "$API_BASE/auth/login" \
    -H "Content-Type: application/json" \
    -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | jq -r '.accessToken')
  
  if [ "$TOKEN" != "null" ] && [ -n "$TOKEN" ]; then
    # Nạp tiền vào ví
    curl -s -X POST "$API_BASE/v1/wallet/topup" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $TOKEN" \
      -d "{\"amount\":$WALLET_AMOUNT}" > /dev/null 2>&1
    
    echo " User $i: $EMAIL - Token ready"
    TOKENS="$TOKENS$TOKEN\n"
  else
    echo "❌ User $i: Failed to get token"
  fi
done

# Lưu tokens vào file
echo -e "$TOKENS" | head -n -1 > /tmp/loadtest_tokens.txt

echo ""
echo " Tokens saved to /tmp/loadtest_tokens.txt"
echo ""
echo "Sử dụng với k6:"
echo "  export ACCESS_TOKEN=\$(head -1 /tmp/loadtest_tokens.txt)"
echo "  make loadtest-local ACCESS_TOKEN=\$ACCESS_TOKEN"
echo ""
echo "Hoặc dùng token đầu tiên:"
head -1 /tmp/loadtest_tokens.txt
