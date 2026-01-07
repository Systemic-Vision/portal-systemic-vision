import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import type { Database } from '@/types/database'

// Server component client
export const createServerClient = () => {
  return createRouteHandlerClient<Database>({ cookies })
}

