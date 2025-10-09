# Copyright The Conforma Contributors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0

FROM alpine:latest

# Build argument to ensure unique image digest each build
ARG BUILD_ID=unknown

# Create a simple application script with build ID
RUN echo '#!/bin/sh' > /app.sh && \
    echo 'echo "=== VSA Generation Demo Application ==="' >> /app.sh && \
    echo 'echo "Build ID: '"${BUILD_ID}"'"' >> /app.sh && \
    echo 'echo "Image: $(hostname)"' >> /app.sh && \
    echo 'echo "Timestamp: $(date)"' >> /app.sh && \
    echo 'echo "This image was built to demonstrate VSA generation"' >> /app.sh && \
    echo 'while true; do' >> /app.sh && \
    echo '  echo "VSA Demo App running at $(date)"' >> /app.sh && \
    echo '  sleep 3600' >> /app.sh && \
    echo 'done' >> /app.sh && \
    chmod +x /app.sh

CMD ["/app.sh"]

