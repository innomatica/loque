# loqueapp

A Simple Podcast App based on [PodcastIndex.org](https://podcastindex.org).

## Limitations

Media seek position is not observed by background audio: this seems to be a limitation of the exoplayer. The result is that when epside A is played half-way 
and new episode B is played, then finished, episode A start at the beginning not at the position when it is left.

