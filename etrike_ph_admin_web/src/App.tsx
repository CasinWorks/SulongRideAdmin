import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider, useAuth } from './hooks/useAuth'
import { DashboardLayout } from './components/layout/DashboardLayout'
import { LoginPage } from './pages/LoginPage'
import {
  DriverAccountPage,
  NotAllowedEmailPage,
  NotInvitedPage,
} from './pages/NotOperatorPage'
import { PendingAccessPage } from './pages/PendingAccessPage'
import { OverviewPage } from './pages/OverviewPage'
import { DriversPage } from './pages/DriversPage'
import { DriverApprovalPage } from './pages/DriverApprovalPage'
import { FarePage } from './pages/FarePage'
import { LeavePage } from './pages/LeavePage'
import { AttendancePage } from './pages/AttendancePage'
import { AuditPage } from './pages/AuditPage'
import { DriverDetailPage } from './pages/DriverDetailPage'
import { DriverOnboardingPage } from './pages/DriverOnboardingPage'
import { TrainingPage } from './pages/TrainingPage'
import { FleetPage } from './pages/FleetPage'
import { FleetVehiclePage } from './pages/FleetVehiclePage'
import { PayrollPage } from './pages/PayrollPage'
import { UsersPage } from './pages/UsersPage'
import { InviteAcceptPage } from './pages/InviteAcceptPage'
import { LoadingState, ScreenLoader } from './components/ui/AdminUi'
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
  const {
    session,
    loading,
    isOperator,
    isDriverAccount,
    operatorLoading,
    emailAllowed,
    operatorStatus,
    operator,
  } = useAuth()

  if (loading || operatorLoading) {
    return <ScreenLoader />
  }

  if (!session) return <Navigate to="/login" replace />
  if (!emailAllowed) return <NotAllowedEmailPage />
  if (isDriverAccount) return <DriverAccountPage />
  if (!operator) return <NotInvitedPage />
  if (operatorStatus === 'revoked') return <PendingAccessPage variant="revoked" />
  if (operatorStatus === 'pending') {
    return <PendingAccessPage variant="pending" />
  }
  if (!isOperator) return <NotInvitedPage />
  return <>{children}</>
}

function AdminRoute({ children }: { children: React.ReactNode }) {
  const { isAdmin, operatorLoading } = useAuth()

  if (operatorLoading) return <LoadingState />
  if (!isAdmin) return <Navigate to="/" replace />
  return <>{children}</>
}

function AppRoutes() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route path="/invite/:token" element={<InviteAcceptPage />} />
      <Route
        element={
          <ProtectedRoute>
            <DashboardLayout />
          </ProtectedRoute>
        }
      >
        <Route index element={<OverviewPage />} />
        <Route path="drivers/onboarding" element={<DriverOnboardingPage />} />
        <Route path="drivers/onboarding/:driverId" element={<DriverOnboardingPage />} />
        <Route path="training" element={<TrainingPage />} />
        <Route path="fleet" element={<FleetPage />} />
        <Route path="fleet/:id" element={<FleetVehiclePage />} />
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
        <Route path="payroll" element={<PayrollPage />} />
        <Route path="leave" element={<LeavePage />} />
        <Route path="fare" element={<FarePage />} />
        <Route path="audit" element={<AuditPage />} />
        <Route
          path="team"
          element={
            <AdminRoute>
              <UsersPage />
            </AdminRoute>
          }
        />
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
