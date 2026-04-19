FROM --platform=linux/amd64 python:3.13-slim-trixie
# Bad as we should call this in command not specified here...
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

RUN apt-get update && apt-get install -y \
    curl \
    gettext \
    postgresql-client libpq-dev \
    gcc \
    make \
    bzip2 \
    git \
    libc6-dev \
    libfreetype6 \
    libsdl1.2debian \
    libfdt1 \
    libglib2.0-0 \
    libsdl2-2.0-0 \
    libpixman-1-0 \
    xvfb \
    nodejs \
    npm \
  --no-install-recommends && rm -rf /var/lib/apt/lists/*


# From VS Code docs
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

# Create the user
RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    #
    # [Optional] Add sudo support. Omit if you don't need to install software after connecting.
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

    # [Optional] Set the default user. Omit if you want to keep the default as root.
USER $USERNAME


# Install pebble-tool via uv
WORKDIR /home/vscode
# Install stpyv8 from pre-built wheel (https://github.com/cloudflare/stpyv8/releases/tag/v13.1.201.22)
# RUN uv pip install --system \
#     https://github.com/cloudflare/stpyv8/releases/download/v13.1.201.22/stpyv8-13.1.201.22-cp313-cp313-manylinux_2_31_x86_64.whl
# RUN uv add stpyv8
RUN uv tool install pebble-tool --python 3.13
ENV PATH="/home/vscode/.local/bin:${PATH}"

# Download and install the Pebble SDK
# `yes` pipes "y" to the TOS acceptance prompt non-interactively.
RUN yes | pebble sdk install latest

RUN npm install @rebble/clay

WORKDIR /workspace
