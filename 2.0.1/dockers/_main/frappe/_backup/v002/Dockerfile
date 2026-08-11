# syntax=docker/dockerfile:1.7

FROM frappe/erpnext:latest

USER root

# ============================================================
# Basic build dependencies
# ============================================================

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*


# ============================================================
# Switch to frappe user
# ============================================================

USER frappe

WORKDIR /home/frappe/frappe-bench


# ============================================================
# Install HRMS
# ============================================================

RUN bench get-app \
    --branch develop \
    https://github.com/frappe/hrms


# ============================================================
# Install HRMS requirements
# ============================================================

RUN bench setup requirements hrms


# ============================================================
# Build HRMS assets
# ============================================================

RUN bench build --app hrms


# ============================================================
# Refresh app list
# ============================================================

RUN ls -1 apps > sites/apps.txt


# ============================================================
# Final user / working directory
# ============================================================

USER frappe

WORKDIR /home/frappe/frappe-bench
