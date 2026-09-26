The install/package.json is largely mirroring the package.json
from nobeBB: https://github.com/NodeBB/NodeBB/blob/master/install/package.json

Our changes from upstream, to carry over on each NodeBB bump (they clear
Dependabot alerts):
- `overrides` lifts vulnerable transitive versions that upstream pins
  (eg nodebb-plugin-dbsearch pins an old lodash).
- `coveralls` is dropped from devDependencies: it pulls in the deprecated
  `request`, which has an unpatched SSRF and no fixed release. We never run
  NodeBB's coverage upload.
