import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import type { Session, User } from '@supabase/supabase-js'
import { supabase } from '../lib/supabase'
import { isEmailAllowedForOperator, oauthRedirectUrl, operatorEmailDomain } from '../lib/operatorAuth'
import { isOperator } from '../services/admin'
import { logAudit } from '../services/audit'

type AuthState = {
  session: Session | null
  user: User | null
  loading: boolean
  isOperator: boolean
  operatorLoading: boolean
  emailAllowed: boolean
  signIn: (email: string, password: string) => Promise<void>
  signInWithGoogle: () => Promise<void>
  signOut: () => Promise<void>
  refreshOperator: () => Promise<void>
}

const AuthContext = createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null)
  const [loading, setLoading] = useState(true)
  const [isOp, setIsOp] = useState(false)
  const [operatorLoading, setOperatorLoading] = useState(false)

  const emailAllowed = isEmailAllowedForOperator(session?.user?.email)

  const refreshOperator = useCallback(async () => {
    if (!session?.user || !isEmailAllowedForOperator(session.user.email)) {
      setIsOp(false)
      return
    }
    setOperatorLoading(true)
    try {
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

  const signInWithGoogle = useCallback(async () => {
    const domain = operatorEmailDomain()
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: oauthRedirectUrl(),
        queryParams: domain ? { hd: domain } : undefined,
      },
    })
    if (error) throw error
  }, [])

  const signOut = useCallback(async () => {
    await logAudit({ action: 'auth.sign_out', summary: 'Operator signed out' })
    await supabase.auth.signOut()
    setIsOp(false)
  }, [])

  const value = useMemo(
    () => ({
      session,
      user: session?.user ?? null,
      loading,
      isOperator: isOp,
      operatorLoading,
      emailAllowed,
      signIn,
      signInWithGoogle,
      signOut,
      refreshOperator,
    }),
    [
      session,
      loading,
      isOp,
      operatorLoading,
      emailAllowed,
      signIn,
      signInWithGoogle,
      signOut,
      refreshOperator,
    ],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth(): AuthState {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth must be used within AuthProvider')
  return ctx
}
