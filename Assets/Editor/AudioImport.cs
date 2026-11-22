using UnityEditor;
using UnityEngine;

namespace CS.EditorTools
{
    /// 음악(Resources/Audio/Music, .ogg)은 압축한 채 메모리에 두고 재생한다 — 레이어 4장을 한꺼번에 풀어 두면 메모리를 많이 먹는다.
    public class AudioImport : AssetPostprocessor
    {
        void OnPreprocessAudio()
        {
            if (!assetPath.Contains("/Resources/Audio/")) return;
            var imp = (AudioImporter)assetImporter;
            bool music = assetPath.EndsWith(".ogg");
            var s = imp.defaultSampleSettings;
            s.loadType = music ? AudioClipLoadType.CompressedInMemory : AudioClipLoadType.DecompressOnLoad;
            s.compressionFormat = AudioCompressionFormat.Vorbis;
            s.quality = music ? 0.6f : 0.8f;
            s.preloadAudioData = true;
            imp.defaultSampleSettings = s;
            imp.loadInBackground = false;
            imp.forceToMono = false;
        }
    }
}
