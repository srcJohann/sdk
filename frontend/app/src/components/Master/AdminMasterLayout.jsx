/**
 * Admin Master Layout
 */
import React from 'react';
import { NavLink, Route, Routes, Navigate } from 'react-router-dom';
import { MasterRoute } from '../../contexts/AuthContext';
import TenantsList from './TenantsList';
import UsersManagement from './UsersManagement';
import MasterSettingsForm from './MasterSettingsForm';
import MasterMetricsDashboard from './MasterMetricsDashboard';
import './AdminMasterLayout.css';

const AdminMasterLayout = () => {
  return (
    <MasterRoute>
      <div className="admin-master-layout">
        <aside className="admin-sidebar">
          <h2>Admin Master</h2>
          <nav>
            <NavLink to="/admin/master/tenants" className={({ isActive }) => isActive ? 'active' : ''}>
              🏢 Tenants
            </NavLink>
            <NavLink to="/admin/master/users" className={({ isActive }) => isActive ? 'active' : ''}>
              👥 Usuários
            </NavLink>
            <NavLink to="/admin/master/settings" className={({ isActive }) => isActive ? 'active' : ''}>
              ⚙️ Configurações
            </NavLink>
            <NavLink to="/admin/master/metrics" className={({ isActive }) => isActive ? 'active' : ''}>
              📊 Métricas
            </NavLink>
          </nav>
        </aside>
        
        <main className="admin-content">
          <Routes>
            <Route path="tenants" element={<TenantsList />} />
            <Route path="users" element={<UsersManagement />} />
            <Route path="settings" element={<MasterSettingsForm />} />
            <Route path="metrics" element={<MasterMetricsDashboard />} />
            <Route path="/" element={<Navigate to="/admin/master/tenants" replace />} />
          </Routes>
        </main>
      </div>
    </MasterRoute>
  );
};

export default AdminMasterLayout;
