## Deploy Consul configurations
```
kubectl apply -f examples/proxy-defaults.yaml
kubectl apply -f examples/mesh.yaml
```

## Deploy token-exchange service
```
kubectl create secret generic token-exchange-env \
  --from-file=.env=examples/token-exchange.env
kubectl apply -f examples/token-exchange.yaml
```

## Deploy ai-agent app
```
kubectl create secret generic ai-agent-env \
  --from-file=.env=examples/ai-agent.env
kubectl apply -f examples/ai-agent.yaml
```

## Deploy web-app
```
kubectl create secret generic web-env \
  --from-file=.env=examples/web-app.env
kubectl apply -f examples/web-app.yaml
```

## Deploy OPA server (if testing OPA)
```
kubectl create ns opa
kubectl apply -n opa -f examples/opa-server.yaml

##Test policies are loaded
kubectl port-forward -n opa svc/opa-service 8080:80
curl -s http://localhost:8080/v1/policies\?pretty\=true | jq -r '.result[] | [.id, .raw] | join("\n")'

kubectl apply -f examples/service-defaults-agent-opa.yaml 
```

## Deploy wx-gov-api (if testing watsonx-governance)
```
kubectl create secret generic wx-gov-api-env --from-env-file=examples/wx-gov-api.env
kubectl apply -f examples/wx-gov-api.yaml

kubectl apply -f examples/service-defaults-agent-wx-gov.yaml 
```

## Configure service-intentions
```
kubectl apply -f examples/service-intentions.yaml
```

## Delete resources
```
kubectl delete secret token-exchange-env
kubectl delete -f examples/token-exchange.yaml

kubectl delete secret ai-agent-env
kubectl delete -f examples/ai-agent.yaml

kubectl delete secret web-env 
kubectl delete -f examples/web-app.yaml

kubectl delete -f examples/service-defaults-agent-opa.yaml 
kubectl delete -n opa -f examples/opa-server.yaml
kubectl delete ns opa

kubectl delete secret wx-gov-api-env
kubectl delete -f examples/wx-gov-api.yaml
kubectl delete -f examples/service-defaults-agent-wx-gov.yaml 

kubectl delete -f examples/mesh.yaml
kubectl delete -f examples/proxy-defaults.yaml
```