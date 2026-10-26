#!/usr/bin/env python3
# ==============================================================================
# mcp_servers/mcp_base.py - 轻量标准 MCP (Model Context Protocol) 核心协议基类
# 
# 无需外部三方依赖，完全兼容 JSON-RPC 2.0 与 Stdio 协议规范。
# 可直接被 Claude Desktop, Claude Code, Cursor, OpenCode 挂载使用。
# ==============================================================================

import json
import sys
import traceback
from typing import Any, Callable, Dict, List, Optional


class MCPServerBase:
    def __init__(self, name: str, version: str = "1.0.0"):
        self.name = name
        self.version = version
        self.tools: Dict[str, Dict[str, Any]] = {}
        self.tool_handlers: Dict[str, Callable[..., Any]] = {}
        self.resources: Dict[str, Dict[str, Any]] = {}
        self.resource_handlers: Dict[str, Callable[..., str]] = {}

    def register_tool(self, name: str, description: str, input_schema: Dict[str, Any], handler: Callable[..., Any]):
        self.tools[name] = {
            "name": name,
            "description": description,
            "inputSchema": input_schema,
        }
        self.tool_handlers[name] = handler

    def register_resource(self, uri: str, name: str, mime_type: str, handler: Callable[..., str]):
        self.resources[uri] = {
            "uri": uri,
            "name": name,
            "mimeType": mime_type,
        }
        self.resource_handlers[uri] = handler

    def handle_request(self, request: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        msg_id = request.get("id")
        method = request.get("method")
        params = request.get("params", {})

        if not method:
            return None

        # 1. 初始化握手
        if method == "initialize":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "protocolVersion": "2024-11-05",
                    "serverInfo": {
                        "name": self.name,
                        "version": self.version,
                    },
                    "capabilities": {
                        "tools": {},
                        "resources": {},
                    },
                },
            }

        elif method in ("notifications/initialized", "initialized"):
            return None

        # 2. 列出 Tools
        elif method == "tools/list":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "tools": list(self.tools.values())
                },
            }

        # 3. 执行 Tool
        elif method == "tools/call":
            tool_name = params.get("name")
            arguments = params.get("arguments", {})

            if tool_name not in self.tool_handlers:
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {
                        "code": -32601,
                        "message": f"Tool '{tool_name}' not found",
                    },
                }

            try:
                result = self.tool_handlers[tool_name](**arguments)
                text_content = result if isinstance(result, str) else json.dumps(result, ensure_ascii=False, indent=2)
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "content": [
                            {
                                "type": "text",
                                "text": text_content,
                            }
                        ]
                    },
                }
            except Exception as e:
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "isError": True,
                        "content": [
                            {
                                "type": "text",
                                "text": f"[Tool Execution Error] {str(e)}\n{traceback.format_exc()}",
                            }
                        ]
                    },
                }

        # 4. 列出 Resources
        elif method == "resources/list":
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "result": {
                    "resources": list(self.resources.values())
                },
            }

        # 5. 读取 Resource
        elif method == "resources/read":
            uri = params.get("uri")
            if uri not in self.resource_handlers:
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32002, "message": f"Resource not found: {uri}"},
                }
            try:
                content = self.resource_handlers[uri]()
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "result": {
                        "contents": [
                            {
                                "uri": uri,
                                "mimeType": self.resources[uri]["mimeType"],
                                "text": content,
                            }
                        ]
                    },
                }
            except Exception as e:
                return {
                    "jsonrpc": "2.0",
                    "id": msg_id,
                    "error": {"code": -32603, "message": f"Resource read failed: {str(e)}"},
                }

        # 6. Ping 心跳
        elif method == "ping":
            return {"jsonrpc": "2.0", "id": msg_id, "result": {}}

        # 未知方法
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "error": {"code": -32601, "message": f"Method not supported: {method}"},
        }

    def run_stdio(self):
        """标准 Stdio 事件循环监听"""
        for line in sys.stdin:
            line = line.strip()
            if not line:
                continue
            try:
                request = json.loads(line)
                response = self.handle_request(request)
                if response is not None:
                    sys.stdout.write(json.dumps(response, ensure_ascii=False) + "\n")
                    sys.stdout.flush()
            except Exception as e:
                sys.stderr.write(f"MCP Stdio Error: {e}\n")
                sys.stderr.flush()
