.PHONY: docker.istio.deb istio.deb sidecar.deb ${OUT}/istio-sidecar.deb

# Make the deb image using the CI/CD image and docker.
docker.istio.deb:
	(cd ${TOP}; docker run --rm -u $(shell id -u) -it \
        -v ${GO_TOP}:${GO_TOP} \
        -w ${PWD} \
        -e USER=${USER} \
        -e GOPATH=${GOPATH} \
		--entrypoint /usr/bin/make ${CI_HUB}/ci:${CI_VERSION} \
		sidecar.deb )

# Create the 'sidecar' deb, including envoy and istio agents and configs.
# This target uses a locally installed 'fpm' - use 'docker.sidecar.deb' to use
# the builder image.
# TODO: consistent layout, possibly /opt/istio-VER/...
sidecar.deb: ${OUT}/istio-sidecar.deb

istio.deb: ${OUT}/istio-sidecar.deb

ISTIO_DEB_SRC=tools/deb/istio-start.sh \
			  tools/deb/istio-iptables.sh \
			  tools/deb/istio.service \
			  tools/deb/istio-auth-node-agent.service \
			  tools/deb/sidecar.env \
			  tools/deb/envoy.json

ISTIO_DEB_DEPS=${ISTIO_BIN}/envoy \
			   ${ISTIO_BIN}/pilot-agent \
			   ${ISTIO_BIN}/node_agent \
			   ${ISTIO_BIN}/istioctl \
			   ${ISTIO_BIN}/mixs \
			   ${ISTIO_BIN}/istio_ca

# Base directory for istio binaries. Likely to change !
ISTIO_DEB_BIN=/usr/local/bin

# TODO: rename istio-sidecar.deb to istio.deb

# Note: adding --deb-systemd ${GO_TOP}/src/istio.io/istio/tools/deb/istio.service will result in
# a /etc/systemd/system/multi-user.target.wants/istio.service and auto-start. Currently not used
# since we need configuration.
# --iteration 1 adds a "-1" suffix to the version that didn't exist before
${OUT}/istio-sidecar.deb: ${ISTIO_DEB_DEPS} ${ISTIO_DEB_SRC}
	mkdir -p ${OUT}
	rm -f ${OUT}/istio-sidecar.deb
	fpm -s dir -t deb -n istio-sidecar -p ${OUT}/istio-sidecar.deb --version ${VERSION} -C ${GO_TOP} -f \
	   --url http://istio.io  \
	   --license Apache \
	   --vendor istio.io \
	   --maintainer istio@istio.io \
	   --after-install tools/deb/postinst.sh \
	   --config-files /var/lib/istio/envoy/sidecar.env \
	   --config-files /var/lib/istio/envoy/envoy.json \
	   --description "Istio" \
	   src/istio.io/istio/tools/deb/istio-start.sh=${ISTIO_DEB_BIN}/istio-start.sh \
	   src/istio.io/istio/tools/deb/istio-iptables.sh=${ISTIO_DEB_BIN}/istio-iptables.sh \
	   src/istio.io/istio/tools/deb/istio.service=/lib/systemd/system/istio.service \
	   src/istio.io/istio/tools/deb/istio-auth-node-agent.service=/lib/systemd/system/istio-auth-node-agent.service \
	   bin/envoy=${ISTIO_DEB_BIN}/envoy \
	   bin/pilot-agent=${ISTIO_DEB_BIN}/pilot-agent \
	   bin/node_agent=${ISTIO_DEB_BIN}/node_agent \
	   bin/istioctl=${ISTIO_DEB_BIN}/istioctl \
	   bin/mixs=${ISTIO_DEB_BIN}/mixs \
	   bin/istio_ca=${ISTIO_DEB_BIN}/istio_ca \
	   bin/pilot-discovery=${ISTIO_DEB_BIN}/pilot-discovery \
       src/istio.io/istio/tools/deb/sidecar.env=/var/lib/istio/envoy/sidecar.env \
	   src/istio.io/istio/tools/deb/envoy.json=/var/lib/istio/envoy/envoy.json

.PHONY: deb-test deb-docker

deb-docker:
	mkdir -p ${OUT}/deb
	cp tools/deb/Dockerfile ${OUT}/deb
	cp ${OUT}/istio-sidecar.deb ${OUT}/deb/istio.deb
	docker build -t istio_deb -f ${OUT}/deb/Dockerfile ${OUT}/deb/


deb-test: deb-docker
	docker run --cap-add=NET_ADMIN --rm -v ${ISTIO_GO}/tools/deb/deb_test.sh:/tmp/deb_test.sh istio_deb /tmp/deb_test.sh

deb-docker-run: deb-docker
	docker run --cap-add=NET_ADMIN --rm -v ${ISTIO_GO}/tools/deb/deb_test.sh:/tmp/deb_test.sh -it istio_deb /bin/bash
