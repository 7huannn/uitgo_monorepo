# UITGo DevOps - Hướng dẫn chạy từ A-Z

## Giải thích các file trong `scripts/`

| File | Mục đích | Khi nào dùng? |
|------|----------|---------------|
| `k8s-dev.sh` | **Script chính** - quản lý cluster | Dùng hàng ngày |
| `demo-presentation.sh` | Demo cho báo cáo (có slides) | Khi báo cáo |
| `setup-local-devops.sh` | Cài đặt ban đầu (k3s, tools) | Chỉ chạy 1 lần |
| `be_bootstrap.sh` | Setup backend development | Chỉ chạy 1 lần |
| `fe_bootstrap.sh` | Setup frontend development | Chỉ chạy 1 lần |
| `RUN_GUIDE.sh` | Hướng dẫn chi tiết từng bước | Tham khảo |

---

## PHẦN 1: SAU KHI MỞ MÁY (Chạy mỗi lần bật máy)

### Bước 1: Mở Terminal và kiểm tra cluster
```bash
cd ~/Workspace/uitgo_monorepo

# Kiểm tra k3s đang chạy không
kubectl get nodes
```

**Nếu báo lỗi "connection refused":**
```bash
sudo systemctl start k3s
sleep 10
kubectl get nodes
```

### Bước 2: Deploy UITGo services
```bash
# Deploy tất cả services
kubectl apply -k k8s/overlays/dev

# Đợi 30 giây rồi kiểm tra
sleep 30
kubectl get pods -n uitgo
```

**Kết quả mong đợi:** Tất cả pods hiển thị `1/1 Running`

### Bước 3: Deploy Monitoring (optional)
```bash
kubectl apply -k k8s/monitoring
kubectl get pods -n monitoring
```

### Bước 4: Mở Terminal MỚI và chạy port-forward
```bash
# QUAN TRỌNG: Mở terminal riêng, KHÔNG đóng terminal này!
cd ~/Workspace/uitgo_monorepo
./scripts/k8s-dev.sh forward
```

Giữ terminal này chạy liên tục trong suốt quá trình làm việc.

### Bước 5: Quay lại Terminal chính, test
```bash
# Test health
curl -s localhost:8081/health
curl -s localhost:8082/health
curl -s localhost:8083/health
```

---

## PHẦN 2: DEMO BÁO CÁO (Step-by-step)

### Chuẩn bị (5 phút trước báo cáo):
```bash
# Terminal 1: Deploy và kiểm tra
cd ~/Workspace/uitgo_monorepo
kubectl apply -k k8s/overlays/dev
kubectl apply -k k8s/monitoring
sleep 30
kubectl get pods -n uitgo

# Terminal 2: Port forward (để chạy liên tục)
cd ~/Workspace/uitgo_monorepo
./scripts/k8s-dev.sh forward

# Mở browser sẵn:
# - http://localhost:3000 (Grafana - admin/uitgo)
# - https://localhost:8443 (ArgoCD)
```

### Khi báo cáo, chạy từng lệnh này:

```bash
# ═══════════════════════════════════════════════════════════════
# SLIDE 1: Kubernetes Cluster
# ═══════════════════════════════════════════════════════════════
kubectl get nodes
kubectl get ns | grep -E "uitgo|monitoring|argocd"

# ═══════════════════════════════════════════════════════════════
# SLIDE 2: Application Pods
# ═══════════════════════════════════════════════════════════════
kubectl get pods -n uitgo
kubectl get svc -n uitgo

# ═══════════════════════════════════════════════════════════════
# SLIDE 3: API Testing
# ═══════════════════════════════════════════════════════════════
# Health check
curl -s localhost:8081/health && echo " ✓ user-service"
curl -s localhost:8082/health && echo " ✓ trip-service"
curl -s localhost:8083/health && echo " ✓ driver-service"

# Đăng ký user mới
curl -s -X POST localhost:8081/auth/register \
  -H "Content-Type: application/json" \
  -d '{"phone":"+84901234567","password":"Demo@123","name":"Demo User","email":"demo@uitgo.com","role":"rider"}' | jq .

# ═══════════════════════════════════════════════════════════════
# SLIDE 4: Monitoring Stack
# ═══════════════════════════════════════════════════════════════
kubectl get pods -n monitoring

# → Mở browser: http://localhost:3000 (Grafana)
# → Login: admin / uitgo

# ═══════════════════════════════════════════════════════════════
# SLIDE 5: ArgoCD GitOps
# ═══════════════════════════════════════════════════════════════
kubectl get pods -n argocd | head -5
kubectl get applications -n argocd

# Lấy password ArgoCD
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo ""

# → Mở browser: https://localhost:8443 (ArgoCD)
# → Login: admin / <password ở trên>

# ═══════════════════════════════════════════════════════════════
# SLIDE 6: Live Deployment (Optional - Ấn tượng!)
# ═══════════════════════════════════════════════════════════════
# Rebuild images sau khi sửa code
./scripts/k8s-dev.sh build

# Restart services
./scripts/k8s-dev.sh restart

# Xem logs real-time
./scripts/k8s-dev.sh logs user-service
```

---

## PHẦN 3: CÁC LỆNH THƯỜNG DÙNG

### Quản lý cluster
```bash
./scripts/k8s-dev.sh status    # Xem trạng thái tất cả
./scripts/k8s-dev.sh forward   # Port forward (terminal riêng)
./scripts/k8s-dev.sh logs <service>  # Xem logs
./scripts/k8s-dev.sh build     # Build lại images
./scripts/k8s-dev.sh restart   # Restart services
./scripts/k8s-dev.sh stop      # Dừng tất cả (xóa pods)
```

### Kubectl cơ bản
```bash
kubectl get pods -n uitgo           # Xem pods
kubectl get svc -n uitgo            # Xem services
kubectl logs -f <pod-name> -n uitgo # Xem logs pod
kubectl describe pod <pod-name> -n uitgo  # Chi tiết pod
```

---

## TROUBLESHOOTING

### Lỗi "No resources found"
```bash
# Deploy lại
kubectl apply -k k8s/overlays/dev
```

### Lỗi "connection refused" khi curl
```bash
# Kiểm tra port-forward đang chạy không
ps aux | grep port-forward

# Nếu không có, chạy lại
./scripts/k8s-dev.sh forward
```

### Pods bị CrashLoopBackOff
```bash
# Xem logs để biết lỗi
kubectl logs <pod-name> -n uitgo

# Thường do database chưa sẵn sàng, đợi 1 phút rồi check lại
```

### Muốn reset hoàn toàn
```bash
./scripts/k8s-dev.sh stop
kubectl apply -k k8s/overlays/dev
```

---

## KIẾN TRÚC HỆ THỐNG

```
┌──────────────────────────────────────────────────────────────┐
│                    Kubernetes (k3s)                          │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │user-service │  │trip-service │  │driver-service│          │
│  │   :8081     │  │   :8082     │  │    :8083    │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐          │
│  │  user-db    │  │  trip-db    │  │ driver-db   │          │
│  │ PostgreSQL  │  │ PostgreSQL  │  │ PostgreSQL  │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │  Prometheus │  │   Grafana   │  │   ArgoCD    │          │
│  │    :9090    │  │    :3000    │  │    :8443    │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
└──────────────────────────────────────────────────────────────┘
```

---

## ACCESS URLs (sau khi port-forward)

| Service | URL | Credentials |
|---------|-----|-------------|
| User Service | http://localhost:8081 | - |
| Trip Service | http://localhost:8082 | - |
| Driver Service | http://localhost:8083 | - |
| Prometheus | http://localhost:9090 | - |
| Grafana | http://localhost:3000 | admin / uitgo |
| ArgoCD | https://localhost:8443 | admin / (xem bằng lệnh) |

---

## CHECKLIST TRƯỚC KHI BÁO CÁO

- [ ] k3s cluster đang chạy (`kubectl get nodes` → Ready)
- [ ] Pods đang chạy (`kubectl get pods -n uitgo` → 7 pods, 1/1 Running)
- [ ] Monitoring đang chạy (`kubectl get pods -n monitoring`)
- [ ] Port-forward đang chạy (terminal riêng)
- [ ] Test thử `curl localhost:8081/health` → `{"status":"ok"}`
- [ ] Mở sẵn Grafana: http://localhost:3000
- [ ] Mở sẵn ArgoCD: https://localhost:8443
