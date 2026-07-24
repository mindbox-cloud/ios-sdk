//
//  MindboxStoriesBlock.swift
//  Mindbox
//
//  Created by Uatkam Utekeshev on 20.07.2026.
//

import UIKit

/// Prototype of an embedded stories strip (Instagram-like) rendered inside a WebView.
/// The host app only places the block; everything else — ring size, content, layout —
/// comes with the block config from the backend, and the rendered page reports its
/// resulting height back through the JS bridge.
public final class MindboxStoriesBlock: MindboxWebViewBlock {

    public init() {
        super.init(url: nil)
        StoriesBlockConfigLoader.fetch { [weak self] config in
            self?.load(html: StoriesFeedTemplate.html(ringSize: config.ringSize))
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

/// Prototype stand-in for the backend: in production the ring size arrives from
/// Mindbox together with the rest of the block config and its content.
enum StoriesBlockConfigLoader {
    struct Config {
        let ringSize: CGFloat
    }

    static func fetch(completion: @escaping (Config) -> Void) {
        // Simulated network latency so the host app's placeholder path gets exercised.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            completion(Config(ringSize: 60))
        }
    }
}

/// Local stories strip markup. Pure CSS (no network, no images) so it renders
/// instantly, works offline, and reload after a process kill is invisible.
enum StoriesFeedTemplate {

    private struct Story {
        let emoji: String
        let name: String
        var seen = false
        var isOwn = false
    }

    static func html(ringSize: CGFloat) -> String {
        let stories: [Story] = [
            Story(emoji: "🙂", name: "Вы", isOwn: true),
            Story(emoji: "🔥", name: "mindbox"),
            Story(emoji: "🛍️", name: "sale_24"),
            Story(emoji: "👟", name: "sneakers"),
            Story(emoji: "☕️", name: "coffee.go"),
            Story(emoji: "🍕", name: "pizza_ho", seen: true),
            Story(emoji: "🎧", name: "musicfan"),
            Story(emoji: "✈️", name: "travelly", seen: true),
            Story(emoji: "📚", name: "bookclub"),
            Story(emoji: "🐈", name: "kotiki", seen: true),
            Story(emoji: "🏋️", name: "fit_pro"),
            Story(emoji: "🌿", name: "ecolife", seen: true),
            Story(emoji: "🎮", name: "gamezone"),
            Story(emoji: "🧁", name: "bakery.m", seen: true)
        ]

        let items = stories.map { story in
            """
            <div class="story">
              <div class="ring\(story.seen ? " seen" : "")">
                <div class="avatar">\(story.emoji)\(story.isOwn ? "<span class=\"plus\">+</span>" : "")</div>
              </div>
              <div class="name">\(story.name)</div>
            </div>
            """
        }.joined()

        let avatarFontSize = Int(ringSize * 0.45)

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
          * { margin: 0; padding: 0; box-sizing: border-box; -webkit-tap-highlight-color: transparent; }
          html, body { overflow: hidden; }
          /* Transparent: the host app's background shows through the block. */
          body { font-family: -apple-system, sans-serif; background: transparent; }
          /* Natural height: the strip is as tall as its content; JS reports it to native. */
          .stories {
            display: flex; gap: 10px;
            padding: 2px 10px; align-items: flex-start;
            overflow-x: auto; overflow-y: hidden;
            -webkit-overflow-scrolling: touch;
          }
          .stories::-webkit-scrollbar { display: none; }
          .story { flex: 0 0 auto; width: \(Int(ringSize))px; text-align: center; }
          .ring {
            width: \(Int(ringSize))px; height: \(Int(ringSize))px; border-radius: 50%; padding: 2px;
            background: conic-gradient(from 45deg, #f09433, #e6683c, #dc2743, #cc2366, #bc1888, #f09433);
          }
          .ring.seen { background: #dbdbdb; }
          .avatar {
            position: relative; width: 100%; height: 100%; border-radius: 50%;
            background: #fafafa; border: 2px solid #fff;
            display: flex; align-items: center; justify-content: center; font-size: \(avatarFontSize)px;
          }
          .plus {
            position: absolute; right: -2px; bottom: -2px;
            width: 14px; height: 14px; border-radius: 50%;
            background: #0095f6; color: #fff; border: 2px solid #fff;
            font-size: 10px; line-height: 10px; font-weight: 700;
            display: flex; align-items: center; justify-content: center;
          }
          .name {
            font-size: 8px; line-height: 10px; color: #262626; margin-top: 2px;
            white-space: nowrap; overflow: hidden; text-overflow: ellipsis;
          }
          @media (prefers-color-scheme: dark) {
            .avatar { background: #262626; border-color: #000; }
            .plus { border-color: #000; }
            .ring.seen { background: #363636; }
            .name { color: #f5f5f5; }
          }
        </style>
        </head>
        <body>
        <div class="stories">\(items)</div>
        <script>
          (function() {
            var strip = document.querySelector('.stories');
            function reportHeight() {
              var handler = window.webkit && window.webkit.messageHandlers
                && window.webkit.messageHandlers.\(MindboxWebViewBlock.heightMessageName);
              if (handler) { handler.postMessage(strip.getBoundingClientRect().height); }
            }
            new ResizeObserver(reportHeight).observe(strip);
            window.addEventListener('load', reportHeight);
          })();
        </script>
        </body>
        </html>
        """
    }
}
