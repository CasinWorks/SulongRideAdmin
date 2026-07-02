import { useEffect, useState, type ReactNode } from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
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
  Menu,
  X,
  Shield,
} from 'lucide-react'
import { useAuth } from '../../hooks/useAuth'
import { PageTransition } from '../ui/AdminMotion'

const baseNav = [
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

const teamNav = { to: '/team', label: 'Team', icon: Shield, end: false as const }

type NavItem = (typeof baseNav)[number] | typeof teamNav

function SidebarBrand() {
  return (
    <div className="mb-6 px-2">
      <p className="text-xs font-medium uppercase tracking-wide text-admin-accent">Sulong Ride</p>
      <h1 className="text-lg font-semibold text-black/87">Admin</h1>
      <p className="text-xs text-black/45">Carmona pilot</p>
    </div>
  )
}

function SidebarNav({
  nav,
  onNavigate,
  onSignOut,
}: {
  nav: NavItem[]
  onNavigate?: () => void
  onSignOut: () => void
}) {
  return (
    <>
      <nav className="flex flex-1 flex-col gap-1 overflow-y-auto">
        {nav.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            onClick={onNavigate}
            className={({ isActive }) => {
              const base = [
                'admin-nav-active flex items-center gap-2.5 rounded-xl px-3 py-2.5',
                'text-sm font-medium transition-colors duration-200',
              ].join(' ')
              return isActive
                ? `${base} bg-admin-accent text-white shadow-sm`
                : `${base} text-black/65 hover:bg-white hover:text-black/87`
            }}
          >
            <Icon size={18} />
            {label}
          </NavLink>
        ))}
      </nav>
      <button
        type="button"
        onClick={onSignOut}
        className={[
          'mt-4 flex items-center gap-2 rounded-xl px-3 py-2.5 text-sm text-black/55',
          'hover:bg-white hover:text-black/80',
        ].join(' ')}
      >
        <LogOut size={18} />
        Sign out
      </button>
    </>
  )
}

function MobileDrawer({
  open,
  onClose,
  children,
}: {
  open: boolean
  onClose: () => void
  children: ReactNode
}) {
  useEffect(() => {
    document.body.style.overflow = open ? 'hidden' : ''
    return () => {
      document.body.style.overflow = ''
    }
  }, [open])

  return (
    <>
      <div
        className={`fixed inset-0 z-40 bg-black/40 transition-opacity lg:hidden ${
          open ? 'opacity-100' : 'pointer-events-none opacity-0'
        }`}
        onClick={onClose}
        aria-hidden={!open}
      />
      <aside
        className={[
          'fixed inset-y-0 left-0 z-50 flex w-[min(18rem,88vw)] flex-col',
          'border-r border-admin-border bg-admin-bg p-4 shadow-xl',
          'transition-transform duration-200 ease-out lg:hidden',
          open ? 'translate-x-0' : '-translate-x-full',
        ].join(' ')}
        aria-hidden={!open}
      >
        <div className="mb-2 flex items-start justify-between gap-2">
          <SidebarBrand />
          <button
            type="button"
            onClick={onClose}
            className="rounded-lg p-2 text-black/55 hover:bg-white hover:text-black/80"
            aria-label="Close menu"
          >
            <X size={20} />
          </button>
        </div>
        {children}
      </aside>
    </>
  )
}

export function DashboardLayout() {
  const { signOut, isSuperAdmin } = useAuth()
  const navigate = useNavigate()
  const location = useLocation()
  const [navOpen, setNavOpen] = useState(false)

  const nav: NavItem[] = isSuperAdmin ? [...baseNav, teamNav] : baseNav

  const currentPage =
    nav.find((item) =>
      item.end ? location.pathname === item.to : location.pathname.startsWith(item.to),
    )?.label ?? 'Admin'

  useEffect(() => {
    setNavOpen(false)
  }, [location.pathname])

  async function handleSignOut() {
    await signOut()
    navigate('/login')
  }

  function closeNav() {
    setNavOpen(false)
  }

  return (
    <div className="flex min-h-screen bg-admin-bg">
      <aside className="hidden w-56 shrink-0 flex-col border-r border-admin-border bg-admin-bg p-4 lg:flex">
        <SidebarBrand />
        <SidebarNav nav={nav} onSignOut={() => void handleSignOut()} />
      </aside>

      <MobileDrawer open={navOpen} onClose={closeNav}>
        <SidebarNav nav={nav} onNavigate={closeNav} onSignOut={() => void handleSignOut()} />
      </MobileDrawer>

      <main className="flex min-w-0 flex-1 flex-col">
        <header className="border-b border-admin-border bg-admin-bg px-4 py-4 sm:px-6 sm:py-5">
          <div className="flex items-start gap-3">
            <button
              type="button"
              onClick={() => setNavOpen(true)}
              className="mt-0.5 rounded-xl border border-admin-border bg-white p-2.5 text-black/70 shadow-sm lg:hidden"
              aria-label="Open menu"
            >
              <Menu size={20} />
            </button>
            <div className="min-w-0 flex-1">
              <p className="text-xs font-medium text-admin-accent lg:hidden">{currentPage}</p>
              <h2 className="text-lg font-semibold text-black/87 sm:text-xl">Operator dashboard</h2>
            </div>
          </div>
        </header>
        <div className="flex-1 overflow-auto p-4 sm:p-6">
          <PageTransition key={location.pathname}>
            <Outlet />
          </PageTransition>
        </div>
      </main>
    </div>
  )
}
