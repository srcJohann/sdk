"""
DOM360 API Module
"""
from .auth_routes import router as auth_router
from .admin import router as admin_router

__all__ = ['auth_router', 'admin_router']
