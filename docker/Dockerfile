FROM ubuntu:22.04

ARG http_proxy
ARG https_proxy
ARG HTTP_PROXY
ARG HTTPS_PROXY
ARG no_proxy
ARG NO_PROXY
ARG USE_USTC_MIRROR=0

SHELL ["/bin/bash", "-lc"]
ENV USE_USTC_MIRROR=${USE_USTC_MIRROR}

COPY . /home/user/qemu-passthrough-test

RUN chmod +x /home/user/qemu-passthrough-test/docker/scripts/*.sh \
    && /home/user/qemu-passthrough-test/docker/scripts/bootstrap-ubuntu.sh

RUN chown -R user:user /home/user/qemu-passthrough-test

USER user
ENV QEMU_BUILD_DIR=/home/user/qemu/build/release
WORKDIR /home/user/qemu-passthrough-test

# Pre-build everything so test commands can run directly after `docker run`.
RUN /home/user/qemu-passthrough-test/docker/scripts/bootstrap-qemu.sh

CMD ["/bin/bash"]
