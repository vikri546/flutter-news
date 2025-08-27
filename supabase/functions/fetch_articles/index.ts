import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'

const NEWS_API_KEY = Deno.env.get('NEWS_API_KEY')
const NEWS_API_URL = 'https://newsapi.org/v2'

serve(async (req) => {
  const { url, method } = req
  const { searchParams } = new URL(url)

  const endpoint = searchParams.get('endpoint') || 'top-headlines'
  const country = searchParams.get('country') || 'us'
  const category = searchParams.get('category')
  const q = searchParams.get('q')
  const page = searchParams.get('page') || '1'
  const pageSize = searchParams.get('pageSize') || '100'

  let apiUrl = `${NEWS_API_URL}/${endpoint}?apiKey=${NEWS_API_KEY}&country=${country}&page=${page}&pageSize=${pageSize}`

  if (category) {
    apiUrl += `&category=${category}`
  }

  if (q) {
    apiUrl += `&q=${q}`
  }

  if (method !== 'GET') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { 'Content-Type': 'application/json' },
    })
  }

  try {
    const response = await fetch(apiUrl)
    const data = await response.json()

    return new Response(JSON.stringify(data), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
