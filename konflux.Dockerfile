# konflux.Dockerfile — build the Eclipse JDT Language Server (JDT-LS) product.
#
# Non-shipping build input: the product is consumed by mta-jdtls-server-base
# (migtools-mta-java-analyzer-bundle), which COPYs it in and runs it as an
# external process. This replaces fetching jdt-language-server-*.tar.gz from
# download.eclipse.org (the allowed_package_sources / PRODSECRM-218 waiver).

# --- Build stage: JDK 21 + Maven (Tycho 5.0.2) ---
FROM registry.redhat.io/ubi9/openjdk-21:latest AS builder
USER root
WORKDIR /build
COPY . .

# JDT-LS requires Java 21+ to build. Use the system `mvn` (3.9.9 in ubi9/openjdk-21,
# which satisfies Tycho 5.0.2) so Maven itself is not fetched over the network.
# -DskipTests avoids the test modules (they pull extra UI deps + a JDK-8/javafx
# target that the product itself does not need).
RUN mvn -B -U clean verify -DskipTests \
        -Dmaven.repo.local=/build/.m2/repository

# The server product is materialized here (per upstream README):
RUN mkdir -p /opt/jdtls \
 && cp -a org.eclipse.jdt.ls.product/target/repository/. /opt/jdtls/

# --- Output stage: a thin carrier for `COPY --from` by the consumer ---
FROM registry.redhat.io/ubi9/ubi-minimal:latest
LABEL name="mta/mta-jdtls-rhel9" \
      summary="Eclipse JDT Language Server build for MTA (non-shipping build input)" \
      distribution-scope="public" \
      url="https://github.com/migtools/mta-eclipse.jdt.ls"
COPY --from=builder /opt/jdtls /opt/jdtls
# Consumer (mta-jdtls-server-base) will: COPY --from=<mta-jdtls image> /opt/jdtls <dest>
