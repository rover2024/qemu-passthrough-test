FROM ubuntu:22.04

SHELL ["/bin/bash", "-lc"]

# Keep script paths stable with README examples.
COPY docker /tmp/docker

RUN chmod +x /tmp/docker/scripts/*.sh \
    && /tmp/docker/scripts/bootstrap-ubuntu.sh

ENV REPOS_DIR=/home/user/repos
ENV INSTALL_DIR=/home/user/install

RUN mkdir -p /home/user/docker "$REPOS_DIR" "$INSTALL_DIR" \
    && cp -a /tmp/docker/. /home/user/docker/ \
    && chown -R user:user /home/user

USER user
WORKDIR /home/user

# Pre-build everything so test commands can run directly after `docker run`.
RUN /home/user/docker/scripts/build-qmsetup.sh \
    && /home/user/docker/scripts/build-qemu.sh \
    && /home/user/docker/scripts/build-sdl2.sh \
    && /home/user/docker/scripts/build-vulkan-headers.sh \
    && /home/user/docker/scripts/build-lorelei.sh

CMD ["/bin/bash"]
