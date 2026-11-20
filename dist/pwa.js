export function enableInstall(root,notice){
 let promptEvent=null;const button=document.createElement('button');button.type='button';button.className='install-button';button.textContent='Zainstaluj TOGETHER';button.hidden=true;root.querySelector('footer').before(button);
 const standalone=matchMedia('(display-mode: standalone)').matches||navigator.standalone===true,ios=/iphone|ipad|ipod/i.test(navigator.userAgent);
 if('serviceWorker' in navigator)addEventListener('load',()=>navigator.serviceWorker.register('/sw.js').catch(()=>{}),{once:true});
 addEventListener('beforeinstallprompt',event=>{event.preventDefault();promptEvent=event;if(!standalone)button.hidden=false;});
 addEventListener('appinstalled',()=>{promptEvent=null;button.hidden=true;notice('TOGETHER zostało zainstalowane.');});
 button.onclick=async()=>{if(promptEvent){promptEvent.prompt();await promptEvent.userChoice;promptEvent=null;button.hidden=true;return;}notice(ios?'Na iPhonie wybierz Udostępnij, a następnie „Do ekranu początkowego”.':'W menu przeglądarki wybierz „Zainstaluj aplikację” lub „Dodaj do ekranu głównego”.');};
 if(!standalone&&ios)button.hidden=false;
}
