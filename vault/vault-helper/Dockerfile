FROM vault

RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 && \
  mv ./jq-linux64 /usr/bin/jq && \
  chmod +x /usr/bin/jq

RUN apk add --no-cache curl

COPY vault-helper.sh /usr/local/bin/vault-helper.sh

RUN chmod +x /usr/local/bin/vault-helper.sh

CMD ["/usr/local/bin/vault-helper.sh"]
