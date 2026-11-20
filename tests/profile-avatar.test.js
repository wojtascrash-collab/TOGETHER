import test from 'node:test';
import assert from 'node:assert/strict';
import { avatarDataUrl, avatarSize, maxAvatarBytes, prepareAvatar, simplifyCanvasWebp } from '../profile-app/avatar-webp.js';

// A real opaque 160 × 160 VP8 image generated with libwebp.
const vp8 = Buffer.from('UklGRnIAAABXRUJQVlA4IGYAAABwCACdASqgAKAAPm02mUmkIyKhIGgAgA2JaW7hdfAAQ9lBDVUmyYh1VJsmIdVSbJiHVUmyYh1VJsmIdVSbJiHVUmyYh1VJsmIdVR+AAP7+D/P//JT/7yv9d24KfJDoNgCAAAAAAAA=', 'base64');
const vp8l = Buffer.from('UklGRiQAAABXRUJQVlA4TBcAAAAvn8AnAAdQsuIVuf8BAEX6/58i+p/6AQA=', 'base64');
function chunk(tag, data) {
  const output = Buffer.alloc(8 + data.length + data.length%2);
  output.write(tag);
  output.writeUInt32LE(data.length,4);
  data.copy(output,8);
  return output;
}
function riff(...chunks) {
  const output=Buffer.concat([Buffer.from('RIFF\0\0\0\0WEBP'),...chunks]);
  output.writeUInt32LE(output.length - 8,4);
  return output;
}
const extended=Buffer.from([0x20,0,0,0,159,0,0,159,0,0]);
const icc=chunk('ICCP',Buffer.from('sRGB fixture'));
const vp8Chunk=vp8.subarray(12);

test('strips extended header and ICC bytes and preserves the coded image',()=>{
  assert.deepEqual(Buffer.from(simplifyCanvasWebp(riff(chunk('VP8X',extended),icc,vp8Chunk))),vp8);
});

test('preserves both already-simple VP8 and VP8L images',()=>{
  for(const candidate of [vp8,vp8l]) assert.deepEqual(Buffer.from(simplifyCanvasWebp(candidate)),candidate);
});

test('rejects malformed, metadata, animated and wrong-sized containers',()=>{
  const corruptLength=Buffer.from(vp8);corruptLength.writeUInt32LE(10000,16);
  const wrongFrameSize=Buffer.from(vp8);wrongFrameSize[26]=159;
  const scaling=Buffer.from(vp8);scaling[27]|=0x40;
  const anim=Buffer.from(extended);anim[0]|=2;
  const wrongCanvas=Buffer.from(extended);wrongCanvas[4]=158;
  for(const candidate of [corruptLength,wrongFrameSize,scaling,vp8.subarray(0,vp8.length-1),
    riff(chunk('VP8X',anim),icc,vp8Chunk),riff(chunk('VP8X',wrongCanvas),icc,vp8Chunk),
    riff(chunk('VP8X',extended),vp8Chunk),riff(chunk('VP8X',extended),icc,icc,vp8Chunk),
    ...['EXIF','XMP ','ANIM','ALPH'].map(tag=>riff(vp8Chunk,chunk(tag,Buffer.from([1])))),riff(vp8Chunk,vp8Chunk)]) {
    assert.equal(simplifyCanvasWebp(candidate),null);
  }
});

function configureCanvas(t, outputs) {
  const qualityAttempts=[];
  const canvas={width:0,height:0,getContext:()=>({fillRect(){},drawImage(){}}),toBlob(done,type,quality){
    assert.equal(canvas.width,avatarSize);
    assert.equal(canvas.height,avatarSize);
    qualityAttempts.push([type, quality]);
    const output = outputs[qualityAttempts.length-1];
    if (output instanceof Error) throw output;
    done(output ?? null);
  }};
  t.mock.method(globalThis, 'btoa', globalThis.btoa);
  const oldDocument=globalThis.document;
  const oldCreateImageBitmap=globalThis.createImageBitmap;
  globalThis.document={createElement:()=>canvas};
  globalThis.createImageBitmap=async()=>({width:160,height:160,close(){}});
  t.after(()=>{globalThis.document=oldDocument;globalThis.createImageBitmap=oldCreateImageBitmap;});
  return qualityAttempts;
}

test('compresses without resizing and accepts exactly 24 KiB after normalizing', async t=>{
  const makeFrame = total => {
    const payload=Buffer.alloc(total-20);vp8.subarray(20).copy(payload);
    return riff(chunk('VP8 ',payload));
  };
  const attempts=configureCanvas(t,[new Blob([makeFrame(maxAvatarBytes+2)],{type:'image/webp'}),
    new Blob([riff(chunk('VP8X',extended),icc,makeFrame(maxAvatarBytes).subarray(12))],{type:'image/webp'})]);
  const result=await prepareAvatar({type:'image/png',size:650});
  assert.equal(Buffer.from(result.base64,'base64').length,maxAvatarBytes);
  assert.deepEqual(attempts,[['image/webp', 0.82], ['image/webp', 0.68]]);
  assert.ok(result.hex.startsWith('\\x52494646'));
});

for (const unsupported of [new Blob(['png'], {type: 'image/png'}), null, new Error('Unsupported')]) {
  test('uses JPEG when the WebP encoder returns ' + String(unsupported), async t => {
    const jpeg = Buffer.from('ffd8ffe0ffd9', 'hex');
    const attempts = configureCanvas(t, [
      unsupported,
      new Blob([Buffer.alloc(maxAvatarBytes + 1)], {type: 'image/jpeg'}),
      new Blob([jpeg], {type: 'image/jpeg'}),
    ]);
    const result = await prepareAvatar({type: 'image/png', size: 650});
    assert.deepEqual(attempts, [['image/webp', 0.82], ['image/jpeg', 0.82], ['image/jpeg', 0.68]]);
    assert.equal(result.hex, '\\x' + jpeg.toString('hex'));
    assert.equal(avatarDataUrl(result.base64), 'data:image/jpeg;base64,' + jpeg.toString('base64'));
  });
}

test('still displays existing WebP and rejects unsupported output from both encoders', async t => {
  const base64 = vp8.toString('base64');
  assert.equal(avatarDataUrl(base64.slice(0, 40) + '\n' + base64.slice(40)), 'data:image/webp;base64,' + base64);
  configureCanvas(t, [null, new Blob(['png'], {type: 'image/png'})]);
  await assert.rejects(prepareAvatar({type: 'image/png', size: 650}), /Nie udało się przygotować miniatury/);
});
