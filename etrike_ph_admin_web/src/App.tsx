import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { DashboardLayout } from './components/layout/DashboardLayout'
import { LoginPage } from './pages/LoginPage'
import { NotAllowedEmailPage, NotOperatorPage } from './pages/NotOperatorPage'
import { OverviewPage } from './pages/OverviewPage'
import { DriversPage } from './pages/DriversPage'
import { DriverApprovalPage } from './pages/DriverApprovalPage'
import { FarePage } from './pages/FarePage'
import { LeavePage } from './pages/LeavePage'
import { AttendancePage } from './pages/AttendancePage'
import { AuditPage } from './pages/AuditPage'
import { DriverDetailPage } from './pages/DriverDetailPage'
import { LoadingState } from './components/ui/AdminUi'
import { isSupabaseConfigured } from './lib/supabase'

function ConfigError() {
  return (
    <div className="flex min-h-screen items-center justify-center bg-admin-bg p-6">
      <div className="max-w-md rounded-2xl border border-admin-border bg-white p-8 text-sm shadow-sm">
        <h1 className="text-lg font-semibold">Supabase not configured</h1>
        <p className="mt-2 text-black/55">
          Copy <code>.env.example</code> to <code>.env.local</code> and set{' '}
          <code>VITE_SUPABASE_URL</code> and <code>VITE_SUPABASE_ANON_KEY</code> (same project as
          the mobile apps).
        </p>
      </div>
    </div>
  )
}

function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { session, loading, isOperator, operatorLoading, emailAllowed } = useAuth()

  if (loading || operatorLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center bg-admin-bg">
        <LoadingState />
      </div>
    )
  }

  if (!session) return <Navigate to="/login" replace />
  if (!emailAllowed) return <NotAllowedEmailPage />
  if (!isOperator) return <NotOperatorPage />
  return <>{children}</>
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<OverviewPage />} />
        <Route path="drivers" element={<DriversPage />} />
        <Route path="drivers/:id" element={<DriverDetailPage />} />
        <Route
          path="pending"
          element={
            <DriverApprovalPage
              status="pending"
              title="Pending approval"
              subtitle="New driver registrations waiting for operator review."
            />
          }
        />
        <Route
          path="approved"
          element={
            <DriverApprovalPage
              status="approved"
              title="Approved drivers"
              subtitle="Active fleet drivers. Revoke to block app access."
              rejectLabel="Revoke"
            />
          }
        />
        <Route
          path="revoked"
          element={
            <DriverApprovalPage
              status="rejected"
              title="Revoked drivers"
              subtitle="Drivers rejected or revoked from the fleet."
              approveLabel="Approve again"
            />
          }
        />
        <Route path="attendance" element={<AttendancePage />} />
        <Route path="leave" element={<LeavePage />} />
        <Route path="fare" element={<FarePage />} />
        <Route path="audit" element={<AuditPage />} />
      </Route>
      <Route path="*" element={<Navigate to="/" replace />} />
    </Routes>
  )
}

export default function App() {
  if (!isSupabaseConfigured()) return <ConfigError />

  return (
    <AuthProvider>
      <BrowserRouter>
        <AppRoutes />
      </BrowserRouter>
    </AuthProvider>
  )
}
