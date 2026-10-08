// The 3D view: a glTF with its clips, in three.js (pinned in index.html's import map). Two cameras: an orbit camera to look around, and the game's, which looks along
// the world's -Z with the creature facing right, orthographic, as the sprites are seen.
import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

export async function createViewer(container, url, opts = {}) {
  const width = opts.width || 720;
  const height = opts.height || 440;
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
  renderer.setSize(width, height);
  container.append(renderer.domElement);
  const scene = new THREE.Scene();
  scene.background = new THREE.Color(0x181a22);
  scene.add(new THREE.HemisphereLight(0xffffff, 0x3a3d4d, 1.5));
  const sun = new THREE.DirectionalLight(0xffffff, 2.2);
  sun.position.set(2, 5, 4);
  scene.add(sun);

  let gltf;
  try {
    gltf = await new GLTFLoader().loadAsync(url);
  } catch (err) {
    renderer.dispose();
    renderer.domElement.remove();
    throw err;
  }
  scene.add(gltf.scene);
  const box = new THREE.Box3().setFromObject(gltf.scene);   // from the rest pose
  const size = box.getSize(new THREE.Vector3());
  const center = box.getCenter(new THREE.Vector3());
  const ground = new THREE.GridHelper(Math.max(size.x, size.z, 0.5) * 3, 12, 0x444a60, 0x2a2e3d);
  ground.position.y = box.min.y;
  scene.add(ground);

  const persp = new THREE.PerspectiveCamera(35, width / height, 0.01, 100);
  const dist = Math.max(size.x, size.y, 0.5) * 2.6;
  const orbitHome = { position: [center.x + dist * 0.55, center.y + size.y * 0.35, center.z + dist * 0.85], target: [center.x, center.y, center.z] };
  const controls = new OrbitControls(persp, renderer.domElement);
  const halfH = Math.max(size.y, 0.5) * 0.7;
  const ortho = new THREE.OrthographicCamera(-halfH * width / height, halfH * width / height, halfH, -halfH, 0.01, 100);
  let mode = "orbit";
  let camera = persp;
  const apply = (state) => {
    persp.position.set(...state.position);
    controls.target.set(...state.target);
    controls.update();
  };
  const orbitCamera = () => { mode = "orbit"; camera = persp; };
  const gameCamera = () => {
    mode = "game";
    camera = ortho;
    ortho.position.set(center.x, center.y, center.z + 10);
    ortho.lookAt(center);
  };
  apply(orbitHome);
  const state = () => ({ mode, position: persp.position.toArray(), target: controls.target.toArray() });
  controls.addEventListener("change", () => { mode = "orbit"; camera = persp; if (opts.onCamera) opts.onCamera(state()); render(); });

  const mixer = new THREE.AnimationMixer(gltf.scene);
  const actions = new Map(gltf.animations.map((clip) => [clip.name, mixer.clipAction(clip)]));
  let current = null;

  function render() {
    renderer.domElement.dataset.camera = mode;
    renderer.render(scene, camera);
  }

  return {
    clips: () => [...actions.keys()],
    duration: (name) => (actions.get(name) ? actions.get(name).getClip().duration : 0),
    play(name) {
      const action = actions.get(name);
      if (!action) throw new Error(`no clip ${name}`);
      if (current) current.stop();
      current = action;
      action.reset().play();
    },
    seek(time) {   // the page's clock, so the model is at the same moment as the sprites
      if (!current) return;
      const d = current.getClip().duration || 1e-6;
      mixer.setTime(time % d);
    },
    render,
    orbitCamera() { orbitCamera(); if (opts.onCamera) opts.onCamera(state()); render(); },
    gameCamera() { gameCamera(); if (opts.onCamera) opts.onCamera(state()); render(); },
    getCamera: state,
    setCamera(s) {
      apply(s);
      if (s.mode === "game") gameCamera(); else orbitCamera();
    },
    dispose() {
      controls.dispose();
      scene.traverse((o) => {
        if (o.geometry) o.geometry.dispose();
        if (o.material) (Array.isArray(o.material) ? o.material : [o.material]).forEach((m) => m.dispose());
      });
      renderer.dispose();
      renderer.forceContextLoss();   // a page that is drawn again and again must not run out of WebGL contexts
      renderer.domElement.remove();
    },
  };
}
