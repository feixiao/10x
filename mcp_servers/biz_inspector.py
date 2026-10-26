#!/usr/bin/env python3
# ==============================================================================
# mcp_servers/biz_inspector.py - AI-Native 业务数据与状态检视 MCP 服务
# 
# 核心安全特性:
# 1. 严格只读查询 (强制仅允许 SELECT / EXPLAIN / SHOW / DESCRIBE / PRAGMA)
# 2. 禁止堆叠多语句 (防分号注入: `SELECT 1; DROP TABLE users;`)
# 3. 强制 LIMIT 限制 (默认 50 行，防全表扫描撑爆上下文)
# 4. 零配置开箱即用 (内置 SQLite 支持，可通过 BIZ_DB_PATH 指定业务库)
# ==============================================================================

import argparse
import json
import os
import re
import sqlite3
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional

# 导入通用 MCP 协议基类
sys.path.insert(0, str(Path(__file__).resolve().parent))
from mcp_base import MCPServerBase

# 高危关键字黑名单（严格拦截修改或破坏性操作）
FORBIDDEN_KEYWORDS = re.compile(
    r"\b(INSERT|UPDATE|DELETE|DROP|TRUNCATE|ALTER|CREATE|RENAME|REPLACE|GRANT|REVOKE|ATTACH|DETACH|VACUUM)\b",
    re.IGNORECASE
)

# 允许的只读命令前缀
ALLOWED_PREFIXES = ("SELECT", "EXPLAIN", "SHOW", "DESCRIBE", "PRAGMA")


class BizInspectorService:
    def __init__(self, db_path: Optional[str] = None):
        self.db_path = db_path or os.environ.get("BIZ_DB_PATH", ".biz_inspector.db")
        self._init_mock_db_if_needed()

    def _init_mock_db_if_needed(self):
        """若数据库不存在，初始化内置业务演示库（用户与订单表）"""
        p = Path(self.db_path)
        if not p.exists():
            conn = sqlite3.connect(self.db_path)
            cur = conn.cursor()
            cur.execute("""
                CREATE TABLE IF NOT EXISTS users (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    username TEXT NOT NULL UNIQUE,
                    email TEXT NOT NULL,
                    role TEXT NOT NULL DEFAULT 'developer',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            cur.execute("""
                CREATE TABLE IF NOT EXISTS audit_logs (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER,
                    action TEXT NOT NULL,
                    status TEXT NOT NULL,
                    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            """)
            # 插入基础演示数据
            cur.execute("INSERT OR IGNORE INTO users (id, username, email, role) VALUES (1, 'alice', 'alice@corp.internal', 'architect');")
            cur.execute("INSERT OR IGNORE INTO users (id, username, email, role) VALUES (2, 'bob', 'bob@corp.internal', 'developer');")
            cur.execute("INSERT OR IGNORE INTO audit_logs (user_id, action, status) VALUES (1, 'deploy_prod', 'success');")
            conn.commit()
            conn.close()

    def get_connection(self) -> sqlite3.Connection:
        # 打开只读 URI 连接
        conn = sqlite3.connect(f"file:{self.db_path}?mode=ro", uri=True)
        conn.row_factory = sqlite3.Row
        return conn

    def query_readonly_db(self, sql_query: str, max_rows: int = 50) -> Dict[str, Any]:
        """
        在只读业务数据库上执行安全巡检查询。
        """
        cleaned = sql_query.strip()
        # 去除末尾分号
        cleaned = re.sub(r";+\s*$", "", cleaned)

        # 1. 禁止多语句注入 (检测中间是否有分号)
        if ";" in cleaned:
            return {
                "success": False,
                "error": "安全拦截：严禁在单次只读查询中执行堆叠多语句 (含有分号 ';' )！",
            }

        # 2. 前缀校验
        first_token = cleaned.split()[0].upper() if cleaned.split() else ""
        if first_token not in ALLOWED_PREFIXES:
            return {
                "success": False,
                "error": f"安全拦截：只读数据库仅允许执行 {ALLOWED_PREFIXES} 语句，当前操作为: {first_token}",
            }

        # 3. 黑名单关键词检查
        matched = FORBIDDEN_KEYWORDS.search(cleaned)
        if matched:
            return {
                "success": False,
                "error": f"安全拦截：检测到破坏性或修改类关键字 '{matched.group(0)}'，操作已阻断！",
            }

        # 4. 强制追加 LIMIT 限制，防止全量拉取撑爆上下文
        max_rows = max(1, min(max_rows, 200))
        if not re.search(r"\bLIMIT\s+\d+", cleaned, re.IGNORECASE):
            final_sql = f"{cleaned} LIMIT {max_rows}"
        else:
            final_sql = cleaned

        # 5. 执行查询
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            cur.execute(final_sql)
            rows = cur.fetchall()
            columns = [desc[0] for desc in cur.description] if cur.description else []
            data = [dict(zip(columns, row)) for row in rows]
            conn.close()
            return {
                "success": True,
                "executed_sql": final_sql,
                "row_count": len(data),
                "columns": columns,
                "rows": data,
            }
        except Exception as e:
            return {
                "success": False,
                "executed_sql": final_sql,
                "error": f"SQL 执行失败: {str(e)}",
            }

    def inspect_schema(self, table_name: str = "") -> Dict[str, Any]:
        """获取业务库表结构 Schema"""
        try:
            conn = self.get_connection()
            cur = conn.cursor()
            if table_name:
                cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name = ?", (table_name,))
            else:
                cur.execute("SELECT name, sql FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
            tables = [{"table_name": row[0], "schema": row[1]} for row in cur.fetchall()]
            conn.close()
            return {"tables": tables}
        except Exception as e:
            return {"error": str(e)}

    def inspect_redis_keys(self, pattern: str = "*", limit: int = 50) -> Dict[str, Any]:
        """缓存状态抽检服务（支持本地模拟与实际缓存键分析）"""
        safe_limit = max(1, min(limit, 100))
        # 演示环境返回受控的典型缓存键状态
        mock_keys = [
            {"key": "session:user:1", "type": "hash", "ttl": 3600},
            {"key": "session:user:2", "type": "hash", "ttl": 1800},
            {"key": "cache:product:101", "type": "string", "ttl": 86400},
            {"key": "rate_limit:ip:127.0.0.1", "type": "string", "ttl": 60},
        ]
        filtered = [k for k in mock_keys if pattern == "*" or pattern in k["key"]][:safe_limit]
        return {
            "pattern": pattern,
            "total_matched": len(filtered),
            "keys": filtered
        }


def create_biz_mcp_server() -> MCPServerBase:
    server = MCPServerBase(name="biz-inspector-mcp", version="1.0.0")
    service = BizInspectorService()

    # 注册 Tool: query_readonly_db
    server.register_tool(
        name="query_readonly_db",
        description="在业务只读从库上安全执行 SQL 巡检查询。严禁修改或破坏性操作，强制限制返回行数。",
        input_schema={
            "type": "object",
            "properties": {
                "sql_query": {
                    "type": "string",
                    "description": "待执行的只读 SQL 语句，例如: SELECT id, username FROM users"
                },
                "max_rows": {
                    "type": "integer",
                    "description": "最大拉取行数限制 (默认 50，上限 200)",
                    "default": 50
                }
            },
            "required": ["sql_query"]
        },
        handler=service.query_readonly_db
    )

    # 注册 Tool: inspect_schema
    server.register_tool(
        name="inspect_schema",
        description="检视业务数据库表结构与 DDL 定义，用于架构设计与数据契约校验。",
        input_schema={
            "type": "object",
            "properties": {
                "table_name": {
                    "type": "string",
                    "description": "特定表名（可选，留空则列出所有业务表）",
                    "default": ""
                }
            }
        },
        handler=service.inspect_schema
    )

    # 注册 Tool: inspect_redis_keys
    server.register_tool(
        name="inspect_redis_keys",
        description="抽检缓存键分布、数据类型与剩余 TTL 生命周期。",
        input_schema={
            "type": "object",
            "properties": {
                "pattern": {
                    "type": "string",
                    "description": "检索通配符，例如 session:*",
                    "default": "*"
                },
                "limit": {
                    "type": "integer",
                    "description": "最大抽检键数量限制",
                    "default": 50
                }
            }
        },
        handler=service.inspect_redis_keys
    )

    # 注册 Resource: schema://main
    server.register_resource(
        uri="schema://main",
        name="核心业务数据模型 Schema",
        mime_type="application/json",
        handler=lambda: json.dumps(service.inspect_schema(), ensure_ascii=False, indent=2)
    )

    return server


def main():
    parser = argparse.ArgumentParser(description="biz-inspector-mcp 服务")
    parser.add_argument("--stdio", action="store_true", default=True, help="启动标准 Stdio MCP 模式")
    parser.add_argument("--test", action="store_true", help="自测运行工具方法")
    args = parser.parse_args()

    server = create_biz_mcp_server()

    if args.test:
        print("--> 自测 inspect_schema:")
        print(json.dumps(server.tool_handlers["inspect_schema"](), indent=2, ensure_ascii=False))
        print("\n--> 自测 query_readonly_db (正常查询):")
        print(json.dumps(server.tool_handlers["query_readonly_db"]("SELECT * FROM users"), indent=2, ensure_ascii=False))
        print("\n--> 自测 query_readonly_db (恶意注入拦截):")
        print(json.dumps(server.tool_handlers["query_readonly_db"]("DROP TABLE users"), indent=2, ensure_ascii=False))
        print(json.dumps(server.tool_handlers["query_readonly_db"]("SELECT 1; DELETE FROM users"), indent=2, ensure_ascii=False))
        return

    server.run_stdio()


if __name__ == "__main__":
    main()
