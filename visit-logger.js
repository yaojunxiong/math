// Shared Supabase visit logger for yaojunxiong.github.io projects.
// Auto-detects site_code:
// - /math/ => math
// - /TypingJapaneseWords/ or minna-* pages => minna
// Optional config:
// window.SITE_VISIT_LOG_CONFIG = { siteCode, siteName, getUser: () => ({ userId, guestUserId, guestUserName, deviceId, deviceFingerprint, locale }) };
(function(){
  const SUPABASE_URL='https://ycjuceortcduakxscfes.supabase.co';
  const SUPABASE_ANON_KEY='sb_publishable_sK-XWyiFwSoKCorddBULCw_0yiS9e5t';
  const cfg=window.SITE_VISIT_LOG_CONFIG||{};
  function detectSiteCode(){
    const p=location.pathname.toLowerCase();
    if(cfg.siteCode)return cfg.siteCode;
    if(p.includes('/typingjapanesewords/')||p.includes('minna-'))return 'minna';
    if(p.includes('/math/'))return 'math';
    return 'unknown';
  }
  function detectSiteName(siteCode){
    if(cfg.siteName)return cfg.siteName;
    if(siteCode==='minna')return 'Minna no Nihongo AI Learning';
    if(siteCode==='math')return 'Multiplication Trainer';
    return document.title||siteCode;
  }
  function uuid(){try{return crypto.randomUUID()}catch(e){return 's_'+Date.now()+'_'+Math.random().toString(36).slice(2)}}
  function sessionId(){let k='site_visit_session_id';let v=sessionStorage.getItem(k);if(!v){v=uuid();sessionStorage.setItem(k,v)}return v}
  async function fingerprint(){
    const raw=[navigator.userAgent,navigator.language,navigator.platform,screen.width,screen.height,Intl.DateTimeFormat().resolvedOptions().timeZone].join('|');
    if(!crypto.subtle)return raw.slice(0,80);
    const buf=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(raw));
    return Array.from(new Uint8Array(buf)).map(b=>b.toString(16).padStart(2,'0')).join('').slice(0,32);
  }
  function fallbackGuest(){
    try{
      const v5=JSON.parse(localStorage.getItem('multiplication-trainer-v5')||'null');
      if(v5&&v5.currentUserId&&Array.isArray(v5.users)){
        const u=v5.users.find(x=>x.id===v5.currentUserId);
        return {guestUserId:v5.currentUserId,guestUserName:u&&u.name};
      }
    }catch(e){}
    return {};
  }
  async function logVisit(){
    try{
      if(!window.supabase)return;
      const siteCode=detectSiteCode();
      const siteName=detectSiteName(siteCode);
      const sb=window.supabase.createClient(SUPABASE_URL,SUPABASE_ANON_KEY);
      const provided=typeof cfg.getUser==='function'?(cfg.getUser()||{}):{};
      const fallback=fallbackGuest();
      const u=Object.assign({},fallback,provided);
      const fp=u.deviceFingerprint||await fingerprint();
      const payload={
        site_code:siteCode,
        site_name:siteName,
        page_url:location.href,
        page_path:location.pathname,
        page_title:document.title,
        referrer:document.referrer||null,
        user_id:u.userId||null,
        guest_user_id:u.guestUserId||null,
        guest_user_name:u.guestUserName||null,
        device_id:u.deviceId||null,
        device_fingerprint:fp,
        session_id:sessionId(),
        user_agent:navigator.userAgent,
        language:navigator.language,
        platform:navigator.platform,
        screen_width:screen.width,
        screen_height:screen.height,
        timezone:Intl.DateTimeFormat().resolvedOptions().timeZone,
        locale:u.locale||localStorage.getItem('math_locale')||document.documentElement.lang||'zh',
        extra:{visibility:document.visibilityState}
      };
      await sb.from('site_visit_logs').insert(payload);
    }catch(e){console.warn('visit log failed',e)}
  }
  function run(){setTimeout(logVisit,800)}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',run);else run();
})();
