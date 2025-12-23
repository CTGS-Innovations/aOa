"""
Session Log Parser for aOa

Parses Claude's session logs to extract file access patterns
and build transition probabilities for predictive prefetch.

Session logs location: ~/.claude/projects/[project-slug]/agent-*.jsonl
"""

import json
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Optional, Tuple
from datetime import datetime

# Import Redis client if available
try:
    from .redis_client import RedisClient
    REDIS_AVAILABLE = True
except ImportError:
    REDIS_AVAILABLE = False


# Redis key prefix for transitions
PREFIX_TRANSITION = "aoa:transition"


class SessionLogParser:
    """Parse Claude session logs to extract file access patterns."""

    def __init__(self, project_path: str = "/home/corey/aOa"):
        """
        Initialize parser for a project.

        Args:
            project_path: Absolute path to the project root
        """
        import os

        # Convert path to slug: /home/corey/aOa -> -home-corey-aOa
        self.project_slug = project_path.replace('/', '-')
        self.project_path = project_path

        # Support Docker volume mount via CLAUDE_SESSIONS env var
        claude_sessions = os.environ.get('CLAUDE_SESSIONS')
        if claude_sessions:
            # Running in Docker with mounted sessions
            self.base_path = Path(claude_sessions) / 'projects' / self.project_slug
        else:
            # Running locally
            self.base_path = Path.home() / '.claude' / 'projects' / self.project_slug

    def list_sessions(self) -> List[Path]:
        """List all agent session files."""
        if not self.base_path.exists():
            return []
        # Agent files contain actual tool calls
        return sorted(self.base_path.glob('agent-*.jsonl'))

    def parse_session(self, session_file: Path) -> List[dict]:
        """
        Extract tool use events from a session file.

        Args:
            session_file: Path to the .jsonl session file

        Returns:
            List of tool events with tool name, input, and timestamp
        """
        events = []
        try:
            with open(session_file, 'r', encoding='utf-8') as f:
                for line in f:
                    if not line.strip():
                        continue
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue

                    # Only process assistant messages with tool calls
                    if entry.get('type') != 'assistant':
                        continue

                    message = entry.get('message', {})
                    content = message.get('content', [])
                    timestamp = entry.get('timestamp', '')

                    # Extract tool_use items from content
                    for item in content:
                        if not isinstance(item, dict):
                            continue
                        if item.get('type') != 'tool_use':
                            continue

                        events.append({
                            'tool': item.get('name', ''),
                            'input': item.get('input', {}),
                            'timestamp': timestamp,
                            'session_file': session_file.name
                        })
        except Exception as e:
            # Log but don't crash on malformed files
            print(f"Warning: Could not parse {session_file}: {e}")

        return events

    def extract_file_reads(self, events: List[dict]) -> List[str]:
        """
        Get ordered list of files read from events.

        Args:
            events: List of tool events from parse_session

        Returns:
            List of file paths in access order
        """
        reads = []
        for e in events:
            if e['tool'] == 'Read':
                file_path = e['input'].get('file_path', '')
                if file_path:
                    reads.append(file_path)
        return reads

    def extract_file_writes(self, events: List[dict]) -> List[str]:
        """
        Get list of files written/edited.

        Args:
            events: List of tool events

        Returns:
            List of file paths that were written or edited
        """
        writes = []
        for e in events:
            if e['tool'] in ('Write', 'Edit'):
                file_path = e['input'].get('file_path', '')
                if file_path:
                    writes.append(file_path)
        return writes

    def normalize_path(self, file_path: str, project_root: str = "/home/corey/aOa") -> str:
        """
        Normalize file path to relative project path.

        Args:
            file_path: Absolute or relative path
            project_root: Project root to make paths relative to

        Returns:
            Relative path from project root, or original if outside project
        """
        if file_path.startswith(project_root):
            rel = file_path[len(project_root):]
            if rel.startswith('/'):
                rel = rel[1:]
            return rel
        return file_path

    def build_transition_matrix(self, normalize: bool = True) -> Dict[str, Dict[str, int]]:
        """
        Build file transition counts across all sessions.

        For each pair of consecutive Read events (A, B), increment
        transitions[A][B] by 1.

        Args:
            normalize: If True, convert absolute paths to relative

        Returns:
            Dict mapping from_file -> {to_file: count}
        """
        transitions: Dict[str, Dict[str, int]] = defaultdict(lambda: defaultdict(int))

        for session_file in self.list_sessions():
            events = self.parse_session(session_file)
            files = self.extract_file_reads(events)

            if normalize:
                files = [self.normalize_path(f) for f in files]

            # Build transitions from consecutive reads
            for i in range(len(files) - 1):
                from_file = files[i]
                to_file = files[i + 1]
                # Skip self-transitions (re-reading same file)
                if from_file != to_file:
                    transitions[from_file][to_file] += 1

        return dict(transitions)

    def get_transition_probabilities(self, from_file: str,
                                     transitions: Dict[str, Dict[str, int]]) -> List[Tuple[str, float]]:
        """
        Get probability distribution for next file given current file.

        Args:
            from_file: Current file being read
            transitions: Transition matrix from build_transition_matrix

        Returns:
            List of (to_file, probability) sorted by probability descending
        """
        if from_file not in transitions:
            return []

        to_counts = transitions[from_file]
        total = sum(to_counts.values())
        if total == 0:
            return []

        probs = [(to_file, count / total) for to_file, count in to_counts.items()]
        return sorted(probs, key=lambda x: x[1], reverse=True)

    def get_stats(self) -> dict:
        """
        Get statistics about parsed sessions.

        Returns:
            Dict with session count, total events, unique files, etc.
        """
        sessions = self.list_sessions()
        total_events = 0
        total_reads = 0
        total_writes = 0
        unique_files = set()

        for session_file in sessions:
            events = self.parse_session(session_file)
            total_events += len(events)

            reads = self.extract_file_reads(events)
            writes = self.extract_file_writes(events)

            total_reads += len(reads)
            total_writes += len(writes)
            unique_files.update(reads)
            unique_files.update(writes)

        return {
            'session_count': len(sessions),
            'total_events': total_events,
            'total_reads': total_reads,
            'total_writes': total_writes,
            'unique_files': len(unique_files),
            'base_path': str(self.base_path)
        }

    def sync_to_redis(self, redis_client: 'RedisClient') -> dict:
        """
        Sync transition matrix to Redis sorted sets.

        For each from_file, creates a sorted set at aoa:transition:{from_file}
        with to_file as member and count as score.

        Args:
            redis_client: RedisClient instance

        Returns:
            Dict with sync statistics
        """
        transitions = self.build_transition_matrix()
        keys_written = 0
        total_transitions = 0

        for from_file, to_files in transitions.items():
            key = f"{PREFIX_TRANSITION}:{from_file}"
            for to_file, count in to_files.items():
                redis_client.zadd(key, count, to_file)
                total_transitions += 1
            keys_written += 1

        return {
            'keys_written': keys_written,
            'total_transitions': total_transitions
        }

    @staticmethod
    def predict_next(redis_client: 'RedisClient', current_file: str,
                     limit: int = 5) -> List[Tuple[str, float]]:
        """
        Predict next files based on transition probabilities.

        Args:
            redis_client: RedisClient instance
            current_file: Current file being accessed
            limit: Max predictions to return

        Returns:
            List of (file_path, probability) tuples
        """
        key = f"{PREFIX_TRANSITION}:{current_file}"

        # Get top transitions by count
        results = redis_client.zrange(key, 0, limit - 1, desc=True, withscores=True)
        if not results:
            return []

        # Calculate total for probability
        total = sum(score for _, score in results)
        if total == 0:
            return []

        return [(file_path, score / total) for file_path, score in results]

    @staticmethod
    def get_all_predictions(redis_client: 'RedisClient', current_files: List[str],
                            limit: int = 5) -> List[Tuple[str, float]]:
        """
        Get predictions based on multiple current files.

        Combines transition probabilities from all current files.

        Args:
            redis_client: RedisClient instance
            current_files: List of files currently being accessed
            limit: Max predictions to return

        Returns:
            List of (file_path, combined_score) tuples
        """
        combined: Dict[str, float] = defaultdict(float)

        for current_file in current_files:
            predictions = SessionLogParser.predict_next(redis_client, current_file, limit=20)
            for file_path, prob in predictions:
                # Avoid predicting files already being accessed
                if file_path not in current_files:
                    combined[file_path] += prob

        # Sort by combined score
        sorted_predictions = sorted(combined.items(), key=lambda x: x[1], reverse=True)
        return sorted_predictions[:limit]


def main():
    """CLI for testing the parser."""
    import argparse
    import os

    parser = argparse.ArgumentParser(description='Parse Claude session logs')
    parser.add_argument('--project', default='/home/corey/aOa',
                        help='Project path to analyze')
    parser.add_argument('--stats', action='store_true',
                        help='Show statistics')
    parser.add_argument('--transitions', action='store_true',
                        help='Build and show transition matrix')
    parser.add_argument('--sync', action='store_true',
                        help='Sync transitions to Redis')
    parser.add_argument('--predict', type=str, metavar='FILE',
                        help='Predict next files for given file')
    parser.add_argument('--top', type=int, default=10,
                        help='Number of top transitions to show')
    parser.add_argument('--redis-url', default=os.environ.get('REDIS_URL', 'redis://localhost:6379/0'),
                        help='Redis URL')

    args = parser.parse_args()

    sp = SessionLogParser(args.project)

    if args.stats:
        stats = sp.get_stats()
        print(f"Sessions: {stats['session_count']}")
        print(f"Total events: {stats['total_events']}")
        print(f"Total reads: {stats['total_reads']}")
        print(f"Total writes: {stats['total_writes']}")
        print(f"Unique files: {stats['unique_files']}")
        print(f"Base path: {stats['base_path']}")

    if args.transitions:
        transitions = sp.build_transition_matrix()
        print(f"\nTransition matrix ({len(transitions)} source files):")

        # Flatten and sort by count
        all_transitions = []
        for from_file, to_files in transitions.items():
            for to_file, count in to_files.items():
                all_transitions.append((from_file, to_file, count))

        all_transitions.sort(key=lambda x: x[2], reverse=True)

        print(f"\nTop {args.top} transitions:")
        for from_file, to_file, count in all_transitions[:args.top]:
            print(f"  {from_file} -> {to_file}: {count}")

    if args.sync:
        if not REDIS_AVAILABLE:
            print("Error: Redis client not available. Run from package context.")
            return

        redis_client = RedisClient(url=args.redis_url)
        if not redis_client.ping():
            print(f"Error: Cannot connect to Redis at {args.redis_url}")
            return

        result = sp.sync_to_redis(redis_client)
        print(f"Synced to Redis:")
        print(f"  Keys written: {result['keys_written']}")
        print(f"  Total transitions: {result['total_transitions']}")

    if args.predict:
        if not REDIS_AVAILABLE:
            print("Error: Redis client not available. Run from package context.")
            return

        redis_client = RedisClient(url=args.redis_url)
        if not redis_client.ping():
            print(f"Error: Cannot connect to Redis at {args.redis_url}")
            return

        predictions = SessionLogParser.predict_next(redis_client, args.predict, limit=args.top)
        if predictions:
            print(f"Predictions for {args.predict}:")
            for file_path, prob in predictions:
                print(f"  {file_path}: {prob:.1%}")
        else:
            print(f"No predictions for {args.predict}")


if __name__ == '__main__':
    main()
