FROM public.ecr.aws/lambda/provided

ENV R_VERSION=4.0.3

RUN yum -y install wget

RUN yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm \
  && wget https://cdn.rstudio.com/r/centos-7/pkgs/R-${R_VERSION}-1-1.x86_64.rpm \
  && yum -y install R-${R_VERSION}-1-1.x86_64.rpm \
  && rm R-${R_VERSION}-1-1.x86_64.rpm

ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

# System requirements for R packages
RUN yum -y install libcurl-devel libxml2-devel openssl-devel tar

#Required packages
RUN echo "options(repos = c(CRAN = 'https://cloud.r-project.org/'), download.file.method = 'libcurl')" >> "/opt/R/${R_VERSION}/lib/R/etc/Rprofile.site"

RUN Rscript -e 'install.packages("remotes")'
RUN Rscript -e 'remotes::install_version("httr", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("jsonlite", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("logger", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("base64enc", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("paws", upgrade="never", version = NULL)'

#Optional packages
RUN Rscript -e 'remotes::install_version("data.table", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("magrittr", upgrade="never", version = NULL)'
RUN Rscript -e 'remotes::install_version("stringr", upgrade="never", version = NULL)'


COPY runtime.R functions.R ${LAMBDA_TASK_ROOT}/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

RUN printf '#!/bin/sh\ncd $LAMBDA_TASK_ROOT\nRscript runtime.R' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap
