## Deploy Consul configurations
```
kubectl apply -f deploy-k8s/proxy-defaults.yaml
kubectl apply -f deploy-k8s/mesh.yaml
```

## Deploy token-exchange service
```
kubectl create secret generic token-exchange-env \
  --from-file=.env=deploy-k8s/token-exchange.env
kubectl apply -f deploy-k8s/token-exchange.yaml
```

## Deploy ai-agent app
```
kubectl create secret generic ai-agent-env \
  --from-file=.env=deploy-k8s/ai-agent.env
kubectl apply -f deploy-k8s/ai-agent.yaml
```

## Deploy web-app
```
kubectl create secret generic web-env \
  --from-file=.env=deploy-k8s/web-app.env
kubectl apply -f deploy-k8s/web-app.yaml
```

## Deploy OPA server (if testing OPA)
```
kubectl create ns opa
kubectl apply -n opa -f deploy-k8s/opa-server.yaml

##Test policies are loaded
kubectl port-forward -n opa svc/opa-service 8080:80
curl -s http://localhost:8080/v1/policies\?pretty\=true | jq -r '.result[] | [.id, .raw] | join("\n")'

#kubectl apply -f deploy-k8s/service-defaults-agent-opa.yaml 
```

## Deploy opa-gov-api (if testing OPA)
```
kubectl apply -f deploy-k8s/opa-gov-api.yaml                                 
kubectl apply -f deploy-k8s/service-defaults-agent-opa-gov.yaml 
```

## Deploy wx-gov-api (if testing watsonx-governance)
```
kubectl create secret generic wx-gov-api-env --from-env-file=deploy-k8s/wx-gov-api.env
kubectl apply -f deploy-k8s/wx-gov-api.yaml

kubectl apply -f deploy-k8s/service-defaults-agent-wx-gov.yaml 
```

## Configure service-intentions
```
kubectl apply -f deploy-k8s/service-intentions.yaml
```

## Delete resources
```
kubectl delete secret token-exchange-env
kubectl delete -f deploy-k8s/token-exchange.yaml

kubectl delete secret ai-agent-env
kubectl delete -f deploy-k8s/ai-agent.yaml

kubectl delete secret web-env 
kubectl delete -f deploy-k8s/web-app.yaml

kubectl delete -f deploy-k8s/service-defaults-agent-opa.yaml 
kubectl delete -n opa -f deploy-k8s/opa-server.yaml
kubectl delete ns opa

kubectl delete secret wx-gov-api-env
kubectl delete -f deploy-k8s/service-defaults-agent-wx-gov.yaml 
kubectl delete -f deploy-k8s/wx-gov-api.yaml

kubectl delete -f deploy-k8s/mesh.yaml
kubectl delete -f deploy-k8s/proxy-defaults.yaml
```