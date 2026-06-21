import App from './App.svelte';
import './styles/app.scss';

const app = new App({
  target: document.getElementById('app') as HTMLElement,
});

export default app;
