import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useState,
  type ReactNode,
} from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { isEmailAllowedForOperator, oauthRedirectUrl, operatorEmailDomain } from '../lib/operatorAuth'
import { fetchCurrentOperator, isDriverAccount, isOperator } from '../services/admin'
import { logAudit } from '../services/audit'
import type { OperatorApprovalStatus, OperatorRole, OperatorRow } from '../types'

type AuthState = {
  session: Session | null
  user: User | null
  loading: boolean
  isOperator: boolean
  isDriverAccount: boolean
  operatorLoading: boolean
  operator: OperatorRow | null
  operatorStatus: OperatorApprovalStatus | 'none'
  operatorRole: OperatorRole | null
  isSuperAdmin: boolean
  isAdmin: boolean
  emailAllowed: boolean
  signIn: (email: string, password: string) => Promise<void>
  signInWithGoogle: (returnPath?: string) => Promise<void>
  signOut: () => Promise<void>
  refreshOperator: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [isOp, setIsOp] = useState(false)
  const [isDriver, setIsDriver] = useState(false)
  const [operator, setOperator] = useState<OperatorRow | null>(null)
  const [operatorLoading, setOperatorLoading] = useState(false)

  const emailAllowed = isEmailAllowedForOperator(session?.user?.email)
  const operatorStatus: OperatorApprovalStatus | 'none' =
    operator?.approval_status ?? 'none'
  const operatorRole = operator?.role ?? null
  const isSuperAdmin = operator?.approval_status === 'approved' && operator.role === 'super_admin'
  const isAdmin =
    operator?.approval_status === 'approved' &&
    (operator.role === 'super_admin' || operator.role === 'admin')

  const refreshOperator = useCallback(async () => {
    if (!session?.user || !isEmailAllowedForOperator(session.user.email)) {
      setIsOp(false)
      setIsDriver(false)
      setOperator(null)
      return
    }
    setOperatorLoading(true)
    try {
      const [current, driver] = await Promise.all([
        fetchCurrentOperator(),
        isDriverAccount(),
      ])
      setOperator(current)
      setIsDriver(driver)
      setIsOp(await isOperator())
    } finally {
      setOperatorLoading(false)
    }
  }, [session?.user])

  useEffect(() => {
    supabase.auth.getSession().then(({ data }) => {
      setSession(data.session)
      setLoading(false)
    })

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((event, next) => {
      setSession(next)
      setLoading(false)
      if (event === 'SIGNED_IN' && next?.user) {
        const provider =
          (next.user.app_metadata?.provider as string | undefined) ?? 'email'
        void logAudit({
          action: 'auth.sign_in',
          summary: 'Operator signed in',
          metadata: { provider },
        })
      }
    })

    return () => subscription.unsubscribe()
  }, [])

  useEffect(() => {
    void refreshOperator()
  }, [refreshOperator])

  const signIn = useCallback(async (email: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
  }, [])

  const signInWithGoogle = useCallback(async (returnPath = '/') => {
    const domain = operatorEmailDomain()
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: oauthRedirectUrl(returnPath),
        queryParams: domain ? { hd: domain } : undefined,
      },
    })
    if (error) throw error
  }, [])

  const signOut = useCallback(async () => {
    await logAudit({ action: 'auth.sign_out', summary: 'Operator signed out' })
    await supabase.auth.signOut()
    setIsOp(false)
    setIsDriver(false)
    setOperator(null)
  }, [])

  const value: AuthState = {
    session,
    user: session?.user ?? null,
    loading,
    isOperator: isOp,
    isDriverAccount: isDriver,
    operatorLoading,
    operator,
    operatorStatus,
    operatorRole,
    isSuperAdmin,
    isAdmin,
    emailAllowed,
    signIn,
    signInWithGoogle,
    signOut,
    refreshOperator,
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
