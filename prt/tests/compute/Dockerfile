FROM cartesi/machine-emulator:0.18.1

USER 0
RUN apt-get -y update && \
    apt-get -y install curl gcc imagemagick make procps xxd pkg-config
ENV FOUNDRY_NIGHTLY nightly-805d7cee81e78e9163b8ce3d86a0c3beb39772d4
RUN curl -sSL https://github.com/foundry-rs/foundry/releases/download/${FOUNDRY_NIGHTLY}/foundry_nightly_linux_$(dpkg --print-architecture).tar.gz | \
    tar -zx -C /usr/local/bin

# prepare debootstrap machine
WORKDIR "/app/tests/compute/program"
RUN curl -sSL https://github.com/cartesi/dave/releases/download/v0.0.8-rc-test/debootstrap-machine-sparsed.tar.gz | \
    tar -zx -C "/app/tests/compute/program"

# prepare doom-showcase machine
RUN curl -sSL https://github.com/cartesi/dave/releases/download/v0.0.9-rc-test/doom-compute-machine.tar.gz | \
    tar -zx -C "/app/tests/compute/program"

# prepare simple machine
RUN curl -sSL https://github.com/cartesi/dave/releases/download/v0.0.10-rc-test/simple-program.tar.gz | \
    tar -zx -C "/app/tests/compute/program"

WORKDIR "/machine/step"
ADD ./machine/step/ .

WORKDIR "/app/contracts"
ADD ./prt/contracts/foundry.toml .
ADD ./prt/contracts/lib/ ./lib/
ADD ./prt/contracts/src/ ./src/
ADD ./prt/contracts/script/ ./script/

RUN forge --version
RUN forge build

ADD ./prt/contracts/deploy_anvil.sh .

WORKDIR "/app/client-lua"
COPY ./prt/client-lua/ .

WORKDIR "/app/tests"
COPY ./prt/tests/common/ ./common
COPY ./prt/tests/compute/ ./compute

RUN chmod +x ./compute/entrypoint.sh
RUN chmod +x ./compute/prt_compute.lua
RUN chmod +x ./compute/doom_showcase/process_doom_graphics.lua

WORKDIR "/app"
RUN mkdir -p pixels
RUN mkdir -p outputs

WORKDIR "/app/tests/compute"
ENTRYPOINT ["./entrypoint.sh"]
