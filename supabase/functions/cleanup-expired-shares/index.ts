const encoder = new TextEncoder();

function constantTimeEquals(left: string, right: string): boolean {
  const a = encoder.encode(left);
  const b = encoder.encode(right);
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);
  for (let i = 0; i < length; i++) diff |= (a[i] ?? 0) ^ (b[i] ?? 0);
  return diff === 0;
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }
  const expected = Deno.env.get('FLUXSHARE_CLEANUP_SECRET');
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const secretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');
  let serverKey: string | undefined;
  if (secretKeys) {
    try {
      serverKey = (JSON.parse(secretKeys) as Record<string, string>).default;
    } catch {
      return Response.json({ error: 'Supabase secret key configuration is invalid' }, { status: 503 });
    }
  }
  serverKey ??= Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!expected || !supabaseUrl || !serverKey) {
    return Response.json({ error: 'Cleanup function is not configured' }, { status: 503 });
  }
  const authorization = request.headers.get('authorization') ?? '';
  if (!constantTimeEquals(authorization, `Bearer ${expected}`)) {
    return new Response('Unauthorized', { status: 401 });
  }

  const headers = {
    apikey: serverKey,
    authorization: `Bearer ${serverKey}`,
    'content-type': 'application/json',
  };
  let removed = 0;
  // Bound one invocation so a large backlog cannot exceed the function limit.
  for (let batch = 0; batch < 10; batch++) {
    const query = new URLSearchParams({
      select: 'id,storage_path',
      expires_at: `lt.${new Date().toISOString()}`,
      order: 'expires_at.asc',
      limit: '100',
    });
    const rowsResponse = await fetch(
      `${supabaseUrl}/rest/v1/share_links?${query}`,
      { headers },
    );
    if (!rowsResponse.ok) {
      return Response.json({ error: 'Could not load expired shares' }, { status: 502 });
    }
    const rows = await rowsResponse.json() as Array<{ id: string; storage_path: string }>;
    if (rows.length === 0) break;

    // Remove the file first. If Storage fails, leave its metadata so the next
    // scheduled run can retry without losing the location of the object.
    const storageResponse = await fetch(`${supabaseUrl}/storage/v1/object/shared-files`, {
      method: 'DELETE',
      headers,
      body: JSON.stringify({ prefixes: rows.map((row) => row.storage_path) }),
    });
    if (!storageResponse.ok) {
      return Response.json({ error: 'Could not remove expired files from Storage' }, { status: 502 });
    }

    const ids = rows.map((row) => row.id);
    const deleteQuery = new URLSearchParams({
      id: `in.(${ids.join(',')})`,
    });
    const deleteResponse = await fetch(
      `${supabaseUrl}/rest/v1/share_links?${deleteQuery}`,
      { method: 'DELETE', headers, },
    );
    if (!deleteResponse.ok) {
      return Response.json({ error: 'Files removed, but expired share rows could not be deleted' }, { status: 502 });
    }
    removed += rows.length;
    if (rows.length < 100) break;
  }
  return Response.json({ removed });
});
