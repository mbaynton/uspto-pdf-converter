FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# -- Core (required for all conversions) --
# qpdf: normalization pipeline (version downgrade, annotation flattening)
# poppler-utils: normalization (pdftocairo) + validation (pdfinfo, pdffonts, pdfimages)
# file: input format detection
# binutils: validation (strings command for multimedia/JS detection)
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        qpdf \
        poppler-utils \
        file \
        binutils \
        ca-certificates \
        curl \
        gnupg && \
    rm -rf /var/lib/apt/lists/*

# -- PostScript (.ps, .eps) --
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends ghostscript && \
    rm -rf /var/lib/apt/lists/*

# -- Images (.jpg, .jpeg, .png, .tiff, .tif, .bmp, .gif) --
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        imagemagick \
        python3-pip && \
    pip3 install --break-system-packages img2pdf && \
    rm -rf /var/lib/apt/lists/*

# -- Office (.doc, .docx, .xls, .xlsx, .ppt, .pptx, .odt, .ods, .odp, .rtf) --
RUN apt-get update -qq && \
    apt-get install -y \
        libreoffice-writer \
        libreoffice-calc \
        libreoffice-impress && \
    rm -rf /var/lib/apt/lists/*

# -- Markdown, plain text, RST (.md, .txt, .rst) and LaTeX (.tex) --
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
        pandoc \
        texlive-latex-base \
        texlive-fonts-recommended \
        texlive-latex-extra && \
    rm -rf /var/lib/apt/lists/*

# -- HTML (.html, .htm) --
# Ubuntu 24.04's chromium-browser is a snap transitional package that does not
# work inside containers. Install Google Chrome from Google's apt repository.
RUN curl -fsSL https://dl.google.com/linux/linux_signing_key.pub \
        | gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] \
        http://dl.google.com/linux/chrome/deb/ stable main" \
        > /etc/apt/sources.list.d/google-chrome.list && \
    apt-get update -qq && \
    apt-get install -y --no-install-recommends google-chrome-stable && \
    rm -rf /var/lib/apt/lists/*

# Copy scripts into the image
COPY . /opt/uspto-pdf-converter
ENV PATH="/opt/uspto-pdf-converter:${PATH}"

WORKDIR /work
ENTRYPOINT ["uspto-pdf-convert.sh"]
