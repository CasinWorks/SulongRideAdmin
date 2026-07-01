import { NavLink, Outlet, useNavigate } from 'react-router-dom'
import {
  LayoutDashboard,
  Users,
  Clock,
  UserCheck,
  UserX,
  CalendarDays,
  Palmtree,
  Banknote,
  ScrollText,
  LogOut,
} from 'lucide-react'
import { useAuth } from '../../hooks/useAuth'

const nav = [
  { to: '/', label: 'Overview', icon: LayoutDashboard, end: true },
  { to: '/drivers', label: 'Drivers', icon: Users },
  { to: '/pending', label: 'Pending', icon: Clock },
  { to: '/approved', label: 'Approved', icon: UserCheck },
  { to: '/revoked', label: 'Revoked', icon: UserX },
  { to: '/attendance', label: 'Attendance', icon: CalendarDays },
  { to: '/leave', label: 'Leave', icon: Palmtree },
  { to: '/fare', label: 'Fare', icon: Banknote },
  { to: '/audit', label: 'Audit logs', icon: ScrollText },
]

export function DashboardLayout() {
  const { signOut } = useAuth()
  const navigate = useNavigate()

  async function handleSignOut() {
    await signOut()
    navigate('/login')
  }

  return (
    <div className="flex min-h-screen bg-admin-bg">
      <aside className="flex w-56 shrink-0 flex-col border-r border-admin-border bg-admin-bg p-4">
        <div className="mb-6 px-2">
          <p className="text-xs font-medium uppercase tracking-wide text-admin-accent">
            Sulong Ride
          </p>
          <h1 className="text-lg font-semibold text-black/87">Admin</h1>
          <p className="text-xs text-black/45">Carmona pilot</p>
        </div>
        <nav className="flex flex-1 flex-col gap-1">
          {nav.map(({ to, label, icon: Icon, end }) => (
            <NavLink
              key={to}
              to={to}
              end={end}
              className={({ isActive }) =>
                `flex items-center gap-2.5 rounded-xl px-3 py-2.5 text-sm font-medium transition ${
                  isActive
                    ? 'bg-admin-accent text-white'
                    : 'text-black/65 hover:bg-white hover:text-black/87'
                }`
              }
            >
              <Icon size={18} />
              {label}
            </NavLink>
          ))}
        </nav>
        <button
          type="button"
          onClick={() => void handleSignOut()}
          className="mt-4 flex items-center gap-2 rounded-xl px-3 py-2.5 text-sm text-black/55 hover:bg-white hover:text-black/80"
        >
          <LogOut size={18} />
          Sign out
        </button>
      </aside>
      <main className="flex-1 overflow-auto">
        <header className="border-b border-admin-border bg-admin-bg px-6 py-5">
          <h2 className="text-xl font-semibold text-black/87">Operator dashboard</h2>
          <p className="text-sm text-black/45">
            Fleet, drivers, fares, and compliance — connected to Supabase
          </p>
        </header>
        <div className="p-6">
          <Outlet />
        </div>
      </main>
    </div>
  )
}
