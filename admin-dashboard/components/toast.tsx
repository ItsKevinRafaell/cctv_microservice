"use client"
import { createContext, useCallback, useContext, useMemo, useState } from 'react'

type Toast = { id: number; message: string; kind?: 'success' | 'error' | 'info' }

const ToastCtx = createContext<{ notify: (msg: string, kind?: Toast['kind']) => void }>({ notify: () => {} })

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([])
  const notify = useCallback((message: string, kind: Toast['kind'] = 'success') => {
    const id = Date.now() + Math.random()
    setToasts((t) => [...t, { id, message, kind }])
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 2200)
  }, [])
  const value = useMemo(() => ({ notify }), [notify])
  return (
    <ToastCtx.Provider value={value}>
      {children}
      <div className="fixed bottom-4 right-4 z-[60] space-y-2">
        {toasts.map((t) => (
          <div
            key={t.id}
            className={
              'px-3 py-2 rounded shadow text-sm border ' +
              (t.kind === 'error'
                ? 'bg-red-600 text-white border-red-700'
                : t.kind === 'info'
                ? 'bg-slate-800 text-white border-slate-900'
                : 'bg-green-600 text-white border-green-700')
            }
          >
            {t.message}
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  )
}

export function useToast() {
  return useContext(ToastCtx)
}

