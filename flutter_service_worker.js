'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "24bc71911b75b5f8135c949e27a2984e",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"manifest.json": "dcdcafd09c58feaba69ea3c6f60eea12",
"naver_redirect.html": "91e43308ce9555443e36e6d9fdf87c2e",
"index.html": "22aa6577ac21e482f72d8ea8b29cb96e",
"/": "22aa6577ac21e482f72d8ea8b29cb96e",
"assets/shaders/stretch_effect.frag": "40d68efbbf360632f614c731219e95f0",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/AssetManifest.bin.json": "d7280b2cdad283258598af871edcb9fb",
"assets/assets/audios/game3_bgm.mp3": "42a1c00f945b1955242a04cffadcded0",
"assets/assets/audios/button_click.mp3": "7f90c47fcc5f15e0c0e94b3bfb6467f7",
"assets/assets/audios/game_success.mp3": "a1a1441cd3415882326d18c3722a453b",
"assets/assets/audios/game_failure.mp3": "ada097d3d4e6b97867c50a328e3af74a",
"assets/assets/audios/game6_bgm.mp3": "fc398af8c9f503fbcc58a6478b5710e4",
"assets/assets/audios/levelTest_success.mp3": "de7c0cf36488e8bae779a91a49d5d0cd",
"assets/assets/audios/levelTest_failure.mp3": "2fecc830ca80995b51d3e57e136d3c32",
"assets/assets/audios/incorrect.mp3": "3fbbb7f9938e1e6c71d934f669f44806",
"assets/assets/audios/correct.mp3": "5ab0d8d4b7e1b840976f0855fd375124",
"assets/assets/videos/char6_run.gif": "d3aaf2bc0445f98cdc590fa1776f7a96",
"assets/assets/videos/char2_run.gif": "f69bbc0528273878fe2325d1e60efd4e",
"assets/assets/videos/char4_run.gif": "8cf599cd52d04f0f7d2524d925fbf3e4",
"assets/assets/videos/char5_run.gif": "0795e675f25828db41b159465af23017",
"assets/assets/videos/char0_run.gif": "87e0703caab1cbafae3161ef9b8c7ce3",
"assets/assets/videos/char1_run.gif": "86ed255b859d71dc3f75103c3a97e03c",
"assets/assets/videos/char3_run.gif": "45a09c6206a73f9872cac0c92555d18b",
"assets/assets/images/covering_cat1.gif": "d9c94dfb2f3a5ae07450a8fb2c8036f0",
"assets/assets/images/game/part6/background.png": "e19d9a01f4cefb54a59828ea110c018d",
"assets/assets/images/game/part6/cake2.png": "c2cadf305db4bf9f4a7eebc6d3eec1b5",
"assets/assets/images/game/part6/cake4.png": "dc332dce10d40373d0d3f0a6776391a5",
"assets/assets/images/game/part6/cake3.png": "276458f10616c318f65c0320bb225a61",
"assets/assets/images/game/part6/cake5.png": "b7ea5a0a0f2cb33dbfe3b4e650b78857",
"assets/assets/images/game/part6/cake1.png": "66c79d918e69e632201f09be3f93208f",
"assets/assets/images/title.png": "9bb098f94f46e8099f243ab897ab60f3",
"assets/assets/images/you_missed_it.png": "30edcd4aaa7989bbcece70bb2aea6edf",
"assets/assets/images/2bingo.png": "f552774582962e3451098674bec36d75",
"assets/assets/images/game2.png": "63eccc24422decfe0e22ca1cdf6301a3",
"assets/assets/images/hanbok_mouse.png": "ae1c63d3afe67b620b6d9717c6f18599",
"assets/assets/images/char/char3.png": "d4a242f4c46670841fffcf2ecb7e64de",
"assets/assets/images/char/char4.png": "0386490b79b30f323ec5e879bdbdabe1",
"assets/assets/images/char/char0.png": "f7a35c1e02b2b56eb0e3c06ad2485288",
"assets/assets/images/char/char5.png": "31883df74861c669e56e5a7056fabe67",
"assets/assets/images/char/char6.png": "b89e21b94c234f6e1f39bd3b9ee957aa",
"assets/assets/images/char/char1.png": "1023b4f0b0b2b2d7236f7a553adf3320",
"assets/assets/images/char/char2.png": "baac8948d7fc34033f3f242a73f905cd",
"assets/assets/images/tear_cat1.png": "6f4406b75a1d9eef740c30cc22dca367",
"assets/assets/images/1bingo.png": "28bb3fe4ce2fe109ba6069f8ebc54246",
"assets/assets/images/game3.png": "1e2095b7259b7eae663a20d918a56054",
"assets/assets/images/wordBook3.png": "7774ca8cbab6783cb562d7f26c21b27b",
"assets/assets/images/failure.png": "3a67633ba8e26d296fbc8e68bf0bbe7b",
"assets/assets/images/google_logo.png": "94ef8a9889d9719028ac1ac3006faed8",
"assets/assets/images/review_cat1.gif": "85df86dbff9e1d216c15be157fd8885d",
"assets/assets/images/chic_mouse.png": "1fb78ba17dab2b2c04f5c5cf5e66e56f",
"assets/assets/images/Saving_Cat1.gif": "fc92f78d80f2dc04a9a5beba375f549c",
"assets/assets/images/wordBook1.png": "4e13f277d19a5074d35b0eb0f9d6c683",
"assets/assets/images/dialog1.png": "a292beeb8a1f68e17ed333079178df34",
"assets/assets/images/princess_mouce.png": "8361dbcc553854b284f6b462bc75eefb",
"assets/assets/images/rank/A2.png": "c595b3cd45bb97baf55512b87c87d1b7",
"assets/assets/images/rank/C2.png": "bf13c662d1695f3d6542e1a76ad7a71e",
"assets/assets/images/rank/C1.png": "19095d6115e446b9c00706a02572a121",
"assets/assets/images/rank/Beginner.png": "fcabe69cc18639bd03f135e235a5d58f",
"assets/assets/images/rank/A1.png": "25024e31ba31ba25064b413ef659a2cb",
"assets/assets/images/rank/B2.png": "b0fbc07523c70c7cc22cad730706637f",
"assets/assets/images/rank/B1.png": "8bb36c374e30b1796b4e378ba5cf8551",
"assets/assets/images/game1.png": "8b7424c561be8b1e1902db1fce8dd3d1",
"assets/assets/images/background/background.png": "b8acb7b585c6258f1072bef21b1859aa",
"assets/assets/images/background/letter.png": "911948f599ed260818dd97118406e848",
"assets/assets/images/background/edit_background.png": "386388c2594d41259a2bb792005de4b8",
"assets/assets/images/background/mailbox_send.gif": "6d9e4342da3e23871f5e963d4179a08b",
"assets/assets/images/background/letter_open.png": "352ed65af187a4343d67939c76dbf62a",
"assets/assets/images/background/mean_cat1.gif": "272b1801eddb001e1074c218858aac96",
"assets/assets/images/background/word_list.png": "51af91b135bfc52d9a8fc42075e67f4e",
"assets/assets/images/background/mailbox.png": "b084d36f9db8a84ff9b2e615186c73fe",
"assets/assets/images/button.png": "55c259b5174cc6eda0822c41910fd36f",
"assets/assets/images/you_had_it.png": "142d1f6c6fcab7526c15421e19a16bd5",
"assets/assets/images/wordBook2.png": "f503a1123b569592ff2e1a77f293c250",
"assets/assets/images/game5.png": "5bee156f22497a9f5a7bc7743904ab27",
"assets/assets/images/hanbok.png": "440e7d6d32020a52e8f9f95416ba034c",
"assets/assets/images/No_review.png": "aeb2a9fdffa4e1eb0835a77dd76c322f",
"assets/assets/images/socketCat1.gif": "f24bd9a13afc2a62873d49cdf010454a",
"assets/assets/images/chic.png": "0f30d2cbdeb95cd339241408f024ab5d",
"assets/assets/images/game6.png": "426fdd9c3c27462870f2446055c63991",
"assets/assets/images/naver_logo.png": "f7bdc070c449c5b03b27a02cef0456f5",
"assets/assets/images/correct.png": "bb0374b306e4f61f3b09ef9f6b56a44c",
"assets/assets/images/princess.png": "7d8fe883f2a35e023983e8a5578ee8db",
"assets/assets/images/game7.png": "5e0dcb117fb5fa1148b61f1d9a05e471",
"assets/assets/images/3bingo.png": "7e22eee681956ce9c540faa3b16ca127",
"assets/assets/images/kakao_logo.png": "d65f1e9ecbeb3f1e45fc15dd6d9ff8e9",
"assets/assets/images/loading_cloud.gif": "907e6e29c547c31d0a445cd7955504b9",
"assets/assets/images/main_character1.png": "f71da3a0e753e319ed20f8453739d286",
"assets/assets/images/game4.png": "dd12578ec854becd9b2f28d9b6211bab",
"assets/assets/images/dialog2.png": "4ca817f0701256b4238d367f847221c3",
"assets/fonts/MaterialIcons-Regular.otf": "b1f6e177044f578d8cb8f25d8c31844f",
"assets/NOTICES": "dd03b5376ff67f9d5684b6c9e9246d1e",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/AssetManifest.bin": "04e51257351db51ad977c037df69a954",
"canvaskit/chromium/canvaskit.wasm": "a726e3f75a84fcdf495a15817c63a35d",
"canvaskit/chromium/canvaskit.js": "a80c765aaa8af8645c9fb1aae53f9abf",
"canvaskit/chromium/canvaskit.js.symbols": "e2d09f0e434bc118bf67dae526737d07",
"canvaskit/skwasm_heavy.wasm": "b0be7910760d205ea4e011458df6ee01",
"canvaskit/skwasm_heavy.js.symbols": "0755b4fb399918388d71b59ad390b055",
"canvaskit/skwasm.js": "8060d46e9a4901ca9991edd3a26be4f0",
"canvaskit/canvaskit.wasm": "9b6a7830bf26959b200594729d73538e",
"canvaskit/skwasm_heavy.js": "740d43a6b8240ef9e23eed8c48840da4",
"canvaskit/canvaskit.js": "8331fe38e66b3a898c4f37648aaf7ee2",
"canvaskit/skwasm.wasm": "7e5f3afdd3b0747a1fd4517cea239898",
"canvaskit/canvaskit.js.symbols": "a3c9f77715b642d0437d9c275caba91e",
"canvaskit/skwasm.js.symbols": "3a4aadf4e8141f284bd524976b1d6bdc",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter_bootstrap.js": "a9e9b706cfff2ceb5b2204c7a1abc7bb",
"version.json": "c09fe602c880b6372e4d2b475165dd97",
"main.dart.js": "c9e7e593fc4de3c94d8970fdf3a016b0"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
