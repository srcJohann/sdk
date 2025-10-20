Deployment notes — ensure frontend is built with correct API URL

Problem observed

- After deploying to VPS the frontend still called http://localhost:3001 (embedded in the built JS), causing CORS errors when the browser attempted to call the backend under a different origin.

Root cause

- The Vite build injects VITE_API_URL at build-time. The production Dockerfile previously ran `npm run build` without passing VITE_API_URL, so the compiled assets fell back to the default `http://localhost:3001`.
- The backend reads `CORS_ORIGINS` from `.env` and is configured to allow origins listed there. The frontend origin (https://sdk.srcjohann.com.br) must be present in `CORS_ORIGINS`.

What I changed

- `Dockerfile.frontend`: added a build ARG `VITE_API_URL` and exported it to the build environment so Vite can read it during `npm run build`.
- `docker-stack.yml`: added `build.args.VITE_API_URL=https://api.srcjohann.com.br` for the frontend so the built assets embed the production API URL.

How to rebuild and redeploy (recommended)

1. Rebuild the frontend image locally (or in your CI):

```bash
# from repository root
docker build -f Dockerfile.frontend --build-arg VITE_API_URL=https://api.srcjohann.com.br -t sdk-frontend:latest .
```

2. Push or update images and deploy the stack (example for Docker Swarm):

```bash
# Build backend (if needed)
docker build -f Dockerfile.backend -t sdk-backend:latest .

# Push images to your registry (optional)
# docker tag sdk-frontend:latest myregistry/sdk-frontend:latest
# docker push myregistry/sdk-frontend:latest

# Deploy stack (assuming docker-stack.yml is configured)
# docker stack deploy -c docker-stack.yml sdk
```

Quick checks after deploy

- Open browser DevTools -> Network. Login request should be sent to `https://api.srcjohann.com.br/api/auth/login` (or same API origin). If it still points to `http://localhost:3001`, the frontend build was not updated and the deployed image is stale.
- Check backend CORS response header in network tab; `access-control-allow-origin` should include `https://sdk.srcjohann.com.br`.

If CORS still fails

- Ensure the backend process has loaded the expected `CORS_ORIGINS` value. In a running container, check env or the `.env` file used by the service.
- Temporary debug: set `CORS_ORIGINS='*'` in the backend env (not recommended for production) to confirm CORS is the issue.

Notes

- Vite inlines environment variables at build-time. Setting `VITE_API_URL` at container runtime (without rebuilding) will not change built static files. That's why passing the build arg is necessary.
- The backend already includes `https://sdk.srcjohann.com.br` in `.env` and `config.py` fallback; confirm the running backend loads the correct `.env`.
