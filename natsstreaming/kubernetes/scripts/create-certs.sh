while :; do
  case $1 in
      # OpenSSL Common Name
      --COMMON-NAME) CN=${2}
      shift;;
      # OpenSSL Country
      --COUNTRY) C=${2}
      shift;;
      # Openssl Organization
      --ORGANIZATION) O=${2}
      shift;;
      # Openssl State/Province
      --STATE) ST=${2}
      shift;;
      *) break
  esac
  shift
done

echo "Generating NATS certificates with the following params:"
echo ""
echo "COMMON-NAME: ${CN}"
echo "COUNTRY: ${C}"
echo "ORGANIZATION: ${O}"
echo "STATE: ${ST}"
echo ""
export CN=$CN
export C=$C
export O=$O
export ST=$ST

if [[ -z ${CN} || -z ${C} || -z ${O} || -z ${ST} ]]; then
    echo "ERROR: One or more required variables were not set"
    echo ""
    echo "Please supply the commands in this order:"
    echo "/create-certs.sh --COMMON-NAME NATS --COUNTRY NL --ORGANIZATION VAMP --STATE Noord-Holland"
    exit 1
fi



mkdir -p ./certs


envsubst < "openssl-nats-client.template" > "openssl-nats-client.cnf"
envsubst < "openssl-nats.template" > "openssl-nats.cnf"

# Create a NATS Certificate Authority
openssl genrsa -des3 -out ./certs/ca.key 4096
openssl req -x509 -new -nodes -key ./certs/ca.key -sha256 -days 1024 -out ./certs/ca.pem


# NATS Client certificates
openssl genrsa -out ./certs/nats-client.key 2048
openssl req -new -sha256 \
     -key ./certs/nats-client.key \
     -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}" \
     -config ./openssl-nats-client.cnf \
     -out ./certs/nats-client.csr
openssl req -in ./certs/nats-client.csr -noout -text
openssl x509 -req -sha256 \
     -days 500 \
     -in ./certs/nats-client.csr \
     -CA ./certs/ca.pem \
     -CAkey ./certs/ca.key \
     -CAcreateserial \
     -extensions v3_req \
     -extfile ./openssl-nats-client.cnf \
     -out ./certs/nats-client.pem
openssl x509 -in ./certs/nats-client.pem -noout -text

# NATS Server certificates
openssl genrsa -out ./certs/nats-server.key 2048
openssl req -new -sha256 \
     -key ./certs/nats-server.key \
     -subj "/C=${C}/ST=${ST}/O=${O}/CN=${CN}" \
     -config ./openssl-nats.cnf \
     -out ./certs/nats-server.csr
openssl req -in ./certs/nats-server.csr -noout -text
openssl x509 -req -sha256 \
     -days 500 \
     -in ./certs/nats-server.csr \
     -CA ./certs/ca.pem \
     -CAkey ./certs/ca.key \
     -CAcreateserial \
     -extensions v3_req \
     -extfile ./openssl-nats.cnf \
     -out ./certs/nats-server.pem
openssl x509 -in ./certs/nats-server.pem -noout -text
openssl x509 -outform der -in ./certs/nats-server.pem -out ./certs/nats-server.crt


echo "
Certificates are created in: cd ./certs

Added them in kubernetes with this command:
kubectl create secret generic nats-certs \
--from-file=ca.pem \
--from-file=nats-client.pem \
--from-file=nats-client.key \
--from-file=nats-server.pem \
--from-file=nats-server.key
"