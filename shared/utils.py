"""
Shared utilities for AI Workflow Demo
Reusable functions across different components
"""

import os
import json
from typing import List, Dict, Any, Optional
from google.cloud import bigquery
from datetime import datetime
import hashlib


class BigQueryHelper:
    """Helper class for BigQuery operations"""

    def __init__(self, project_id: str, dataset_id: str = "knowledge_base"):
        self.client = bigquery.Client(project=project_id)
        self.project_id = project_id
        self.dataset_id = dataset_id

    def insert_rows(self, table_id: str, rows: List[Dict[str, Any]]) -> Optional[List[Dict]]:
        """Insert rows into BigQuery table"""
        table_ref = f"{self.project_id}.{self.dataset_id}.{table_id}"
        errors = self.client.insert_rows_json(table_ref, rows)

        if errors:
            print(f"Errors inserting rows: {errors}")
            return errors
        return None

    def query(self, sql: str) -> List[Dict[str, Any]]:
        """Run a query and return results as list of dicts"""
        query_job = self.client.query(sql)
        results = []

        for row in query_job.result():
            results.append(dict(row))

        return results

    def stream_insert(self, table_id: str, rows: List[Dict[str, Any]]):
        """Stream insert for real-time data"""
        table_ref = self.client.dataset(self.dataset_id).table(table_id)
        errors = self.client.insert_rows_json(table_ref, rows)

        if errors:
            raise Exception(f"BigQuery insert errors: {errors}")


class VectorHelper:
    """Helper for vector operations (embeddings)"""

    @staticmethod
    def cosine_similarity(vec1: List[float], vec2: List[float]) -> float:
        """Calculate cosine similarity between two vectors"""
        import numpy as np
        return float(np.dot(vec1, vec2) / (np.linalg.norm(vec1) * np.linalg.norm(vec2)))

    @staticmethod
    def find_most_similar(
        query_vector: List[float],
        candidate_vectors: List[List[float]],
        top_k: int = 5
    ) -> List[tuple]:
        """
        Find top-k most similar vectors
        Returns list of (index, similarity_score) tuples
        """
        similarities = [
            (i, VectorHelper.cosine_similarity(query_vector, vec))
            for i, vec in enumerate(candidate_vectors)
        ]
        similarities.sort(key=lambda x: x[1], reverse=True)
        return similarities[:top_k]


class DataValidator:
    """Validate and sanitize data"""

    @staticmethod
    def validate_email(email: str) -> bool:
        """Basic email validation"""
        import re
        pattern = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
        return bool(re.match(pattern, email))

    @staticmethod
    def sanitize_text(text: str, max_length: int = 1000) -> str:
        """Sanitize text input"""
        # Remove control characters
        text = ''.join(char for char in text if ord(char) >= 32 or char == '\n')
        # Truncate if too long
        if len(text) > max_length:
            text = text[:max_length] + "..."
        return text.strip()

    @staticmethod
    def validate_shopify_order(order: Dict[str, Any]) -> bool:
        """Validate Shopify order structure"""
        required_fields = ['id', 'email', 'total_price', 'line_items']
        return all(field in order for field in required_fields)


class AIResponseParser:
    """Parse and extract structured data from LLM responses"""

    @staticmethod
    def extract_json(text: str) -> Optional[Dict[str, Any]]:
        """Extract JSON from text (handles markdown code blocks)"""
        # Try to find JSON in markdown code block
        import re
        json_pattern = r'```(?:json)?\s*(\{.*?\})\s*```'
        match = re.search(json_pattern, text, re.DOTALL)

        if match:
            try:
                return json.loads(match.group(1))
            except json.JSONDecodeError:
                pass

        # Try to find raw JSON
        json_pattern = r'\{.*\}'
        match = re.search(json_pattern, text, re.DOTALL)

        if match:
            try:
                return json.loads(match.group(0))
            except json.JSONDecodeError:
                pass

        return None

    @staticmethod
    def extract_list(text: str, delimiter: str = '\n') -> List[str]:
        """Extract list items from text"""
        lines = text.split(delimiter)
        items = []

        for line in lines:
            # Remove markdown list markers
            line = line.strip()
            if line.startswith('- ') or line.startswith('* '):
                items.append(line[2:].strip())
            elif line.startswith(tuple(f"{i}. " for i in range(10))):
                items.append(line.split('. ', 1)[1].strip())
            elif line:
                items.append(line)

        return [item for item in items if item]


class MetricsLogger:
    """Log metrics and analytics"""

    def __init__(self, bq_helper: BigQueryHelper):
        self.bq = bq_helper

    def log_interaction(
        self,
        interaction_type: str,
        metadata: Dict[str, Any]
    ):
        """Log user interaction"""
        row = {
            'timestamp': datetime.utcnow().isoformat(),
            'interaction_type': interaction_type,
            'metadata': json.dumps(metadata)
        }
        self.bq.insert_rows('interactions', [row])

    def log_llm_call(
        self,
        model: str,
        prompt_tokens: int,
        completion_tokens: int,
        latency_ms: float
    ):
        """Log LLM API call metrics"""
        row = {
            'timestamp': datetime.utcnow().isoformat(),
            'model': model,
            'prompt_tokens': prompt_tokens,
            'completion_tokens': completion_tokens,
            'latency_ms': latency_ms,
            'total_tokens': prompt_tokens + completion_tokens
        }
        # Could insert to a metrics table
        print(f"LLM Call: {model}, {row['total_tokens']} tokens, {latency_ms}ms")


class CacheHelper:
    """Simple in-memory cache for embeddings and responses"""

    def __init__(self, max_size: int = 1000):
        self.cache: Dict[str, Any] = {}
        self.max_size = max_size

    def get_key(self, text: str) -> str:
        """Generate cache key from text"""
        return hashlib.md5(text.encode()).hexdigest()

    def get(self, text: str) -> Optional[Any]:
        """Get cached value"""
        key = self.get_key(text)
        return self.cache.get(key)

    def set(self, text: str, value: Any):
        """Set cached value"""
        if len(self.cache) >= self.max_size:
            # Simple LRU: remove first item
            self.cache.pop(next(iter(self.cache)))

        key = self.get_key(text)
        self.cache[key] = value

    def clear(self):
        """Clear cache"""
        self.cache.clear()


class SlackFormatter:
    """Format messages for Slack"""

    @staticmethod
    def create_message_block(title: str, text: str, color: str = "good") -> Dict:
        """Create Slack message block"""
        return {
            "attachments": [
                {
                    "color": color,
                    "title": title,
                    "text": text,
                    "footer": "AI Workflow Demo",
                    "ts": int(datetime.utcnow().timestamp())
                }
            ]
        }

    @staticmethod
    def create_alert(severity: str, message: str) -> Dict:
        """Create alert message"""
        colors = {
            "info": "#36a64f",
            "warning": "#ff9900",
            "error": "#ff0000"
        }

        icons = {
            "info": "ℹ️",
            "warning": "⚠️",
            "error": "🚨"
        }

        return {
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": f"{icons.get(severity, '•')} {severity.upper()} Alert"
                    }
                },
                {
                    "type": "section",
                    "text": {
                        "type": "mrkdwn",
                        "text": message
                    }
                }
            ]
        }


# Utility functions

def get_env_or_error(key: str) -> str:
    """Get environment variable or raise error"""
    value = os.getenv(key)
    if not value:
        raise ValueError(f"Environment variable {key} is required but not set")
    return value


def chunk_list(items: List[Any], chunk_size: int) -> List[List[Any]]:
    """Split list into chunks"""
    return [items[i:i + chunk_size] for i in range(0, len(items), chunk_size)]


def truncate_text(text: str, max_length: int = 100, suffix: str = "...") -> str:
    """Truncate text to max length"""
    if len(text) <= max_length:
        return text
    return text[:max_length - len(suffix)] + suffix


def format_currency(amount: float, currency: str = "USD") -> str:
    """Format currency amount"""
    symbols = {"USD": "$", "EUR": "€", "GBP": "£"}
    symbol = symbols.get(currency, currency + " ")
    return f"{symbol}{amount:,.2f}"
