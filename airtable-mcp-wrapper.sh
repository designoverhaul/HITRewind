#!/bin/bash

# Airtable MCP Server Wrapper
export AIRTABLE_API_KEY="pat9HXwt4uUaLl3SC.3a38959399a2a1d101c726e5e3ce154b37661244db837be7698a27cd18fd764b"
export AIRTABLE_BASE_ID="appxCBIOkiJEZiph7"

exec /usr/local/bin/airtable-mcp-server "$@" 