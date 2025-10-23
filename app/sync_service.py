"""
Data synchronization service for cross-device sync and offline capability.
Handles bi-directional sync, conflict resolution, and incremental updates.
"""

import os
import logging
import json
from typing import Dict, Any, List, Optional, Tuple
from datetime import datetime, timedelta
from dataclasses import dataclass
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, desc
from .models import (
    DatabaseManager, UserProfile, UserProgress, QuizAttempt, Lesson, Quiz,
    Attempt, Error, Progress, ProgressCreate, AttemptCreate, ErrorCreate
)
from .cache_service import CacheService

logger = logging.getLogger(__name__)


@dataclass
class SyncItem:
    """Represents a single item for synchronization."""
    table_name: str
    item_id: str
    user_id: str
    data: Dict[str, Any]
    updated_at: datetime
    operation: str  # 'create', 'update', 'delete'
    client_timestamp: Optional[datetime] = None
    conflict_resolution: str = 'server_wins'  # 'server_wins', 'client_wins', 'manual'


@dataclass
class SyncResult:
    """Results of a synchronization operation."""
    success: bool
    items_synced: int
    conflicts_resolved: int
    errors: List[str]
    last_sync_timestamp: datetime
    sync_summary: Dict[str, Any]


class SyncService:
    """Service for handling data synchronization across devices."""

    def __init__(self, db_manager: DatabaseManager, cache_service: CacheService = None):
        """
        Initialize sync service.

        Args:
            db_manager: Database manager instance
            cache_service: Optional cache service for performance
        """
        self.db_manager = db_manager
        self.cache_service = cache_service

        # Sync configuration
        self.sync_batch_size = 100
        self.max_sync_age_days = 30
        self.conflict_resolution_strategy = 'server_wins'

        # Tables to sync (in dependency order)
        self.syncable_tables = [
            'user_profiles',
            'lessons',
            'quizzes',
            'attempts',
            'errors',
            'user_progress',
            'quiz_attempts',
            'progress'
        ]

        logger.info("Sync service initialized")

    def sync_user_data(self, user_id: str, client_data: List[SyncItem], last_sync: Optional[datetime] = None) -> SyncResult:
        """
        Synchronize user data between client and server.

        Args:
            user_id: User identifier
            client_data: Data from client to sync
            last_sync: Last synchronization timestamp

        Returns:
            Sync result with summary and conflicts
        """
        try:
            logger.info(f"Starting data sync for user {user_id}, {len(client_data)} client items")

            # Get server changes since last sync
            server_changes = self._get_server_changes(user_id, last_sync)

            # Detect and resolve conflicts
            conflicts = self._detect_conflicts(client_data, server_changes)
            resolved_conflicts = self._resolve_conflicts(conflicts)

            # Apply client changes to server
            client_applied = self._apply_client_changes(user_id, client_data, resolved_conflicts)

            # Get updated server changes for client
            updated_server_changes = self._get_server_changes(user_id, last_sync)

            # Update last sync timestamp
            sync_timestamp = datetime.utcnow()
            self._update_last_sync(user_id, sync_timestamp)

            # Prepare result
            result = SyncResult(
                success=True,
                items_synced=len(client_data) + len(updated_server_changes),
                conflicts_resolved=len(resolved_conflicts),
                errors=[],
                last_sync_timestamp=sync_timestamp,
                sync_summary={
                    'client_items_applied': client_applied,
                    'server_items_for_client': len(updated_server_changes),
                    'conflicts': len(conflicts),
                    'sync_timestamp': sync_timestamp.isoformat()
                }
            )

            logger.info(f"Sync completed for user {user_id}: {result.items_synced} items, {result.conflicts_resolved} conflicts resolved")
            return result

        except Exception as e:
            logger.error(f"Sync failed for user {user_id}: {e}")
            return SyncResult(
                success=False,
                items_synced=0,
                conflicts_resolved=0,
                errors=[str(e)],
                last_sync_timestamp=datetime.utcnow(),
                sync_summary={}
            )

    def get_incremental_changes(self, user_id: str, since: Optional[datetime] = None, table_names: List[str] = None) -> List[SyncItem]:
        """
        Get incremental changes for a user since a specific timestamp.

        Args:
            user_id: User identifier
            since: Timestamp to get changes since
            table_names: Optional list of specific tables to sync

        Returns:
            List of sync items with changes
        """
        try:
            if since is None:
                since = datetime.utcnow() - timedelta(days=self.max_sync_age_days)

            tables_to_check = table_names or self.syncable_tables
            changes = []

            session = self.db_manager.get_session()
            try:
                # Get changes from each table
                for table_name in tables_to_check:
                    table_changes = self._get_table_changes(session, user_id, table_name, since)
                    changes.extend(table_changes)

                logger.info(f"Retrieved {len(changes)} incremental changes for user {user_id} since {since}")
                return changes

            finally:
                session.close()

        except Exception as e:
            logger.error(f"Failed to get incremental changes: {e}")
            return []

    def push_offline_queue(self, user_id: str, offline_actions: List[Dict[str, Any]]) -> SyncResult:
        """
        Process offline actions queue and sync to server.

        Args:
            user_id: User identifier
            offline_actions: List of offline actions to process

        Returns:
            Sync result
        """
        try:
            logger.info(f"Processing {len(offline_actions)} offline actions for user {user_id}")

            processed_actions = []
            errors = []

            session = self.db_manager.get_session()
            try:
                for action in offline_actions:
                    try:
                        result = self._process_offline_action(session, user_id, action)
                        if result:
                            processed_actions.append(action)
                    except Exception as e:
                        errors.append(f"Failed to process action {action.get('id', 'unknown')}: {str(e)}")

                session.commit()

                logger.info(f"Processed {len(processed_actions)} offline actions for user {user_id}")
                return SyncResult(
                    success=len(errors) == 0,
                    items_synced=len(processed_actions),
                    conflicts_resolved=0,
                    errors=errors,
                    last_sync_timestamp=datetime.utcnow(),
                    sync_summary={
                        'offline_actions_processed': len(processed_actions),
                        'failed_actions': len(errors)
                    }
                )

            except Exception as e:
                session.rollback()
                logger.error(f"Failed to process offline queue: {e}")
                return SyncResult(
                    success=False,
                    items_synced=0,
                    conflicts_resolved=0,
                    errors=[str(e)],
                    last_sync_timestamp=datetime.utcnow(),
                    sync_summary={}
                )
            finally:
                session.close()

        except Exception as e:
            logger.error(f"Failed to push offline queue: {e}")
            return SyncResult(
                success=False,
                items_synced=0,
                conflicts_resolved=0,
                errors=[str(e)],
                last_sync_timestamp=datetime.utcnow(),
                sync_summary={}
            )

    def get_sync_status(self, user_id: str) -> Dict[str, Any]:
        """
        Get synchronization status for a user.

        Args:
            user_id: User identifier

        Returns:
            Sync status information
        """
        try:
            last_sync = self._get_last_sync(user_id)
            pending_changes = len(self.get_incremental_changes(user_id, last_sync))

            status = {
                'user_id': user_id,
                'last_sync': last_sync.isoformat() if last_sync else None,
                'pending_changes': pending_changes,
                'sync_enabled': True,
                'conflict_resolution': self.conflict_resolution_strategy,
                'sync_tables': self.syncable_tables
            }

            logger.info(f"Sync status for user {user_id}: {pending_changes} pending changes")
            return status

        except Exception as e:
            logger.error(f"Failed to get sync status: {e}")
            return {
                'user_id': user_id,
                'last_sync': None,
                'pending_changes': 0,
                'sync_enabled': False,
                'error': str(e)
            }

    def export_user_data(self, user_id: str) -> Dict[str, Any]:
        """
        Export all user data for backup or migration.

        Args:
            user_id: User identifier

        Returns:
            Complete user data export
        """
        try:
            logger.info(f"Exporting data for user {user_id}")

            session = self.db_manager.get_session()
            try:
                export_data = {
                    'user_id': user_id,
                    'export_timestamp': datetime.utcnow().isoformat(),
                    'data': {}
                }

                # Export data from each table
                for table_name in self.syncable_tables:
                    table_data = self._export_table_data(session, user_id, table_name)
                    export_data['data'][table_name] = table_data

                logger.info(f"Data export completed for user {user_id}")
                return export_data

            finally:
                session.close()

        except Exception as e:
            logger.error(f"Failed to export user data: {e}")
            raise

    def import_user_data(self, user_id: str, import_data: Dict[str, Any], merge_strategy: str = 'replace') -> bool:
        """
        Import user data from backup or migration.

        Args:
            user_id: User identifier
            import_data: Data to import
            merge_strategy: 'replace' or 'merge'

        Returns:
            True if successful
        """
        try:
            logger.info(f"Importing data for user {user_id} with strategy {merge_strategy}")

            session = self.db_manager.get_session()
            try:
                # Import data to each table
                for table_name, table_data in import_data.get('data', {}).items():
                    if table_name in self.syncable_tables:
                        self._import_table_data(session, user_id, table_name, table_data, merge_strategy)

                session.commit()
                logger.info(f"Data import completed for user {user_id}")
                return True

            except Exception as e:
                session.rollback()
                logger.error(f"Failed to import user data: {e}")
                raise
            finally:
                session.close()

        except Exception as e:
            logger.error(f"Failed to import user data: {e}")
            return False

    # Private Methods

    def _get_server_changes(self, user_id: str, since: Optional[datetime]) -> List[SyncItem]:
        """Get changes from server since timestamp."""
        return self.get_incremental_changes(user_id, since)

    def _detect_conflicts(self, client_data: List[SyncItem], server_changes: List[SyncItem]) -> List[Tuple[SyncItem, SyncItem]]:
        """Detect conflicts between client and server data."""
        conflicts = []

        # Create lookup for server changes
        server_lookup = {(item.table_name, item.item_id): item for item in server_changes}

        for client_item in client_data:
            server_item = server_lookup.get((client_item.table_name, client_item.item_id))
            if server_item and self._is_conflict(client_item, server_item):
                conflicts.append((client_item, server_item))

        logger.info(f"Detected {len(conflicts)} conflicts")
        return conflicts

    def _is_conflict(self, client_item: SyncItem, server_item: SyncItem) -> bool:
        """Check if two items are in conflict."""
        # Items conflict if both have been modified since last sync
        # and have different data
        if client_item.data != server_item.data:
            if client_item.client_timestamp and server_item.updated_at:
                # Check if both were modified around the same time
                time_diff = abs((client_item.client_timestamp - server_item.updated_at).total_seconds())
                return time_diff < 60  # Conflict if modified within 60 seconds
        return False

    def _resolve_conflicts(self, conflicts: List[Tuple[SyncItem, SyncItem]]) -> List[SyncItem]:
        """Resolve conflicts based on strategy."""
        resolved = []

        for client_item, server_item in conflicts:
            if self.conflict_resolution_strategy == 'server_wins':
                resolved.append(server_item)
            elif self.conflict_resolution_strategy == 'client_wins':
                resolved.append(client_item)
            else:
                # Use timestamp for resolution
                if client_item.client_timestamp and server_item.updated_at:
                    if client_item.client_timestamp > server_item.updated_at:
                        resolved.append(client_item)
                    else:
                        resolved.append(server_item)
                else:
                    resolved.append(server_item)  # Default to server

        return resolved

    def _apply_client_changes(self, user_id: str, client_data: List[SyncItem], resolved_conflicts: List[SyncItem]) -> int:
        """Apply client changes to server."""
        applied_count = 0

        # Create lookup for resolved conflicts
        conflict_lookup = {(item.table_name, item.item_id): item for item in resolved_conflicts}

        session = self.db_manager.get_session()
        try:
            for client_item in client_data:
                # Skip if this item was resolved in favor of server
                conflict_item = conflict_lookup.get((client_item.table_name, client_item.item_id))
                if conflict_item and conflict_item != client_item:
                    continue

                # Apply the change
                if self._apply_sync_item(session, client_item):
                    applied_count += 1

            session.commit()

        except Exception as e:
            session.rollback()
            logger.error(f"Failed to apply client changes: {e}")
            raise
        finally:
            session.close()

        return applied_count

    def _apply_sync_item(self, session: Session, sync_item: SyncItem) -> bool:
        """Apply a single sync item to the database."""
        try:
            if sync_item.table_name == 'user_profiles':
                return self._sync_user_profile(session, sync_item)
            elif sync_item.table_name == 'user_progress':
                return self._sync_user_progress(session, sync_item)
            elif sync_item.table_name == 'quiz_attempts':
                return self._sync_quiz_attempt(session, sync_item)
            elif sync_item.table_name == 'attempts':
                return self._sync_attempt(session, sync_item)
            elif sync_item.table_name == 'errors':
                return self._sync_error(session, sync_item)
            elif sync_item.table_name == 'progress':
                return self._sync_progress(session, sync_item)
            else:
                logger.warning(f"Unknown table for sync: {sync_item.table_name}")
                return False

        except Exception as e:
            logger.error(f"Failed to apply sync item: {e}")
            return False

    def _sync_user_profile(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync user profile data."""
        profile_repo = self.db_manager.get_profile_repository()
        profile_repo.update_profile(sync_item.user_id, sync_item.data)
        return True

    def _sync_user_progress(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync user progress data."""
        progress_repo = self.db_manager.get_progress_repository()
        update_data = sync_item.data.copy()
        lesson_id = update_data.pop('lesson_id', None)
        if lesson_id:
            progress_repo.update_progress(sync_item.user_id, lesson_id, update_data)
            return True
        return False

    def _sync_quiz_attempt(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync quiz attempt data."""
        # This would need a proper QuizAttempt repository
        # For now, return True as placeholder
        return True

    def _sync_attempt(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync attempt data."""
        attempt_repo = self.db_manager.get_attempt_repository()
        attempt_data = AttemptCreate(**sync_item.data)
        attempt_repo.create_attempt(attempt_data)
        return True

    def _sync_error(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync error data."""
        error_repo = self.db_manager.get_error_repository()
        error_data = ErrorCreate(**sync_item.data)
        error_repo.create_error(error_data)
        return True

    def _sync_progress(self, session: Session, sync_item: SyncItem) -> bool:
        """Sync progress analytics data."""
        progress_repo = self.db_manager.get_progress_analytics_repository()
        progress_data = ProgressCreate(**sync_item.data)
        progress_repo.create_or_update_progress(progress_data)
        return True

    def _get_table_changes(self, session: Session, user_id: str, table_name: str, since: datetime) -> List[SyncItem]:
        """Get changes from a specific table."""
        changes = []

        try:
            if table_name == 'user_profiles':
                # Get user profile changes
                profile = session.query(UserProfile).filter(
                    UserProfile.user_id == user_id,
                    UserProfile.updated_at > since
                ).first()

                if profile:
                    changes.append(SyncItem(
                        table_name=table_name,
                        item_id=profile.user_id,
                        user_id=user_id,
                        data={
                            'display_name': profile.display_name,
                            'preferred_level': profile.preferred_level,
                            'settings': profile.settings or {}
                        },
                        updated_at=profile.updated_at,
                        operation='update'
                    ))

            # Add other table handlers as needed
            # This is a simplified implementation

        except Exception as e:
            logger.error(f"Failed to get changes from table {table_name}: {e}")

        return changes

    def _process_offline_action(self, session: Session, user_id: str, action: Dict[str, Any]) -> bool:
        """Process a single offline action."""
        try:
            action_type = action.get('type')
            action_data = action.get('data', {})

            if action_type == 'lesson_view':
                # Track lesson view
                lesson_id = action_data.get('lesson_id')
                if lesson_id:
                    progress_repo = self.db_manager.get_progress_repository()
                    progress_repo.update_progress(user_id, lesson_id, {'lesson_views': 1})
                    return True

            elif action_type == 'quiz_attempt':
                # Record quiz attempt
                quiz_data = action_data.get('quiz_data', {})
                if quiz_data:
                    # This would create a quiz attempt record
                    return True

            elif action_type == 'profile_update':
                # Update profile
                profile_data = action_data.get('profile_data', {})
                if profile_data:
                    profile_repo = self.db_manager.get_profile_repository()
                    profile_repo.update_profile(user_id, profile_data)
                    return True

            return False

        except Exception as e:
            logger.error(f"Failed to process offline action: {e}")
            return False

    def _export_table_data(self, session: Session, user_id: str, table_name: str) -> List[Dict[str, Any]]:
        """Export data from a specific table."""
        data = []

        try:
            if table_name == 'user_profiles':
                profile = session.query(UserProfile).filter(
                    UserProfile.user_id == user_id
                ).first()
                if profile:
                    data.append({
                        'user_id': profile.user_id,
                        'display_name': profile.display_name,
                        'preferred_level': profile.preferred_level,
                        'settings': profile.settings or {}
                    })

            # Add other table export handlers as needed

        except Exception as e:
            logger.error(f"Failed to export data from table {table_name}: {e}")

        return data

    def _import_table_data(self, session: Session, user_id: str, table_name: str, table_data: List[Dict[str, Any]], merge_strategy: str) -> None:
        """Import data to a specific table."""
        try:
            if table_name == 'user_profiles':
                for item in table_data:
                    profile_repo = self.db_manager.get_profile_repository()
                    profile_repo.update_profile(user_id, item)

            # Add other table import handlers as needed

        except Exception as e:
            logger.error(f"Failed to import data to table {table_name}: {e}")
            raise

    def _get_last_sync(self, user_id: str) -> Optional[datetime]:
        """Get last sync timestamp for user."""
        try:
            if self.cache_service:
                cached_sync = self.cache_service.get(f"last_sync:{user_id}")
                if cached_sync:
                    return datetime.fromisoformat(cached_sync)

            # Fallback to database or default
            return None

        except Exception as e:
            logger.error(f"Failed to get last sync timestamp: {e}")
            return None

    def _update_last_sync(self, user_id: str, timestamp: datetime) -> None:
        """Update last sync timestamp for user."""
        try:
            if self.cache_service:
                self.cache_service.set(f"last_sync:{user_id}", timestamp.isoformat(), expire_minutes=43200)  # 30 days

        except Exception as e:
            logger.error(f"Failed to update last sync timestamp: {e}")


# Exception Classes
class SyncError(Exception):
    """Synchronization related errors."""
    pass


class ConflictResolutionError(Exception):
    """Conflict resolution related errors."""
    pass