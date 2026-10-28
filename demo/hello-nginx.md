# hello-nginx.yaml — Sample Web App on AKS

[`hello-nginx.yaml`](hello-nginx.yaml) deploys a small "Hello World" web page to the AKS cluster created by [`aks.ps1`](aks.ps1). It runs **two nginx pods** behind an **Azure public load balancer**, and each page shows the name of the pod that served it. This makes it easy to demonstrate replicas, load balancing, and scaling during a presentation.

The manifest contains five Kubernetes objects, separated by `---`:

| # | Kind | Name | Purpose |
|---|------|------|---------|
| 1 | `Namespace` | `demo` | Keeps all demo objects together so they are easy to find and delete. |
| 2 | `ConfigMap` | `hello-html` | Holds the `index.html` page that nginx serves. |
| 3 | `ConfigMap` | `nginx-conf` | Holds an nginx site configuration that enables Server Side Includes (SSI). |
| 4 | `Deployment` | `hello-nginx` | Runs two `nginx:1.27` pods that mount both ConfigMaps. |
| 5 | `Service` | `hello-nginx` | Type `LoadBalancer`; gives the pods a public IP address on port 80. |

## How the pieces fit together

```text
Browser ──► Azure Load Balancer (public IP, port 80)
                   │   Service: hello-nginx (selector app=hello-nginx)
          ┌────────┴────────┐
          ▼                 ▼
   Pod hello-nginx-…-a   Pod hello-nginx-…-b
   nginx:1.27            nginx:1.27
   /usr/share/nginx/html ◄── ConfigMap hello-html (index.html)
   /etc/nginx/conf.d     ◄── ConfigMap nginx-conf (default.conf)
```

## Object-by-object walkthrough

### 1. Namespace `demo`

```yaml
kind: Namespace
metadata:
  name: demo
```

Every other object sets `namespace: demo`. Remember to add `-n demo` to `kubectl` commands, or the objects will not appear (the default namespace is `default`).

### 2. ConfigMap `hello-html`

The `index.html` key contains the web page:

- The `<meta>` tags ask the browser **not to cache** the page, so each refresh is a new request that can be sent to a different pod.
- `<!--#echo var="hostname" -->` is an nginx **SSI directive**. When SSI is on, nginx replaces it with the value of its built-in `$hostname` variable. Inside a pod, the hostname is the **pod name**, so the page reads, for example, `Served by Pod: hello-nginx-7c9d8f6b5-x2k4p`.

### 3. ConfigMap `nginx-conf`

The `default.conf` key is a minimal nginx server block:

```nginx
server {
  listen 80;
  location / {
    root /usr/share/nginx/html;
    index index.html;
    ssi on;
  }
}
```

It replaces the image's default site configuration. The only real change from the default is `ssi on;`, which makes the `hostname` placeholder work. Without it, the browser would receive the SSI comment unchanged and show an empty pod name.

### 4. Deployment `hello-nginx`

| Setting | Value | Meaning |
|---------|-------|---------|
| `replicas` | `2` | Kubernetes keeps two pods running and replaces any that fail. |
| `selector.matchLabels` / `template.metadata.labels` | `app: hello-nginx` | Links the Deployment (and the Service) to its pods. These labels must match. |
| `image` | `nginx:1.27` | Official nginx image, pinned to a minor version for repeatable demos. |
| `containerPort` | `80` | The port nginx listens on inside the container. |
| `volumes` + `volumeMounts` | `html`, `conf` | Mounts each ConfigMap as files in the container. |

The two mounts **replace** the whole target directory:

- `hello-html` → `/usr/share/nginx/html` — the default nginx welcome page is replaced by `index.html`.
- `nginx-conf` → `/etc/nginx/conf.d` — the default `default.conf` is replaced by the SSI-enabled version.

ConfigMap volumes are read-only, which is fine because nginx only reads these files.

### 5. Service `hello-nginx`

```yaml
spec:
  type: LoadBalancer
  selector:
    app: hello-nginx
  ports:
  - port: 80
    targetPort: 80
```

- `selector: app: hello-nginx` sends traffic to every ready pod with that label.
- `type: LoadBalancer` tells AKS to create an **Azure Load Balancer rule and a public IP address**. It can take a minute or two for the address to appear.
- `port: 80` is the port exposed by the Service; `targetPort: 80` is the container port it forwards to.

## Deploy and test

Run these after `aks.ps1` has finished and `kubectl` is connected to the cluster.

```powershell
# Create all five objects
kubectl apply -f hello-nginx.yaml

# Watch the pods start (Ctrl+C to stop watching)
kubectl get pods -n demo -o wide --watch

# Wait for EXTERNAL-IP to change from <pending> to an address
kubectl get service hello-nginx -n demo --watch
```

Open `http://<EXTERNAL-IP>` in a browser. You should see:

> **Hello World from AKS!**
> Served by Pod: hello-nginx-xxxxxxxxxx-xxxxx

You can also test from PowerShell:

```powershell
$ip = kubectl get service hello-nginx -n demo -o jsonpath="{.status.loadBalancer.ingress[0].ip}"
1..6 | ForEach-Object { (Invoke-WebRequest "http://$ip" -UseBasicParsing).Content | Select-String "Served by Pod" }
```

**Note:** A browser often reuses the same keep-alive connection, so several refreshes in a row may show the same pod. Use a new private window, wait a few seconds between refreshes, or use the PowerShell loop above to see both pods answer.

## Demo ideas

```powershell
# Scale out and watch new pod names appear on the page
kubectl scale deployment hello-nginx -n demo --replicas=4
kubectl get pods -n demo

# Self-healing: delete a pod and watch Kubernetes replace it
kubectl delete pod -n demo <pod-name>
kubectl get pods -n demo --watch

# Inspect the objects
kubectl describe deployment hello-nginx -n demo
kubectl get configmap hello-html -n demo -o yaml
kubectl get endpoints hello-nginx -n demo
kubectl logs -n demo -l app=hello-nginx
```

### Changing the page

Edit the `index.html` section in `hello-nginx.yaml`, then reapply and restart the pods so the change appears right away:

```powershell
kubectl apply -f hello-nginx.yaml
kubectl rollout restart deployment hello-nginx -n demo
kubectl rollout status deployment hello-nginx -n demo
```

Mounted ConfigMap files are updated automatically after a short delay, but nginx only rereads `default.conf` when it reloads or restarts. A rollout restart covers both cases.

## Troubleshooting

**`EXTERNAL-IP` stays `<pending>`:** Wait a few minutes, then check events with `kubectl describe service hello-nginx -n demo`. Public IP quota or subscription policies can block load balancer creation.

**Page shows `Served by Pod:` with no name:** SSI is not active. Confirm that the `nginx-conf` ConfigMap is mounted at `/etc/nginx/conf.d` and contains `ssi on;`.

**Default "Welcome to nginx!" page appears:** The `hello-html` ConfigMap is not mounted. Check `kubectl describe pod -n demo <pod-name>` for volume errors.

**Pods not `Running`:** Use `kubectl describe pod -n demo <pod-name>` and `kubectl logs -n demo <pod-name>` to see image pull or configuration errors.

## Cleanup

Remove only the sample app (the AKS cluster keeps running):

```powershell
kubectl delete -f hello-nginx.yaml
# or
kubectl delete namespace demo
```

Deleting the Service also removes its Azure public IP and load balancer rule. To delete the AKS cluster itself, follow the **Cleanup** section in [README.md](README.md).

## References

- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Kubernetes ConfigMaps](https://kubernetes.io/docs/concepts/configuration/configmap/)
- [Kubernetes Service type LoadBalancer](https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer)
- [Use a public load balancer in AKS](https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard)
- [nginx SSI module](https://nginx.org/en/docs/http/ngx_http_ssi_module.html)

