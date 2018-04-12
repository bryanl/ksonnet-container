local k = import "k.libsonnet";

{
    // nodeAffinity creates a node affinity or anti-affinity
    //
    // * @param key The label key this affinity applies to
    // * @param values An array of string values
    // * @param operator Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.
    // * @param weight Weight for this affinity in the range 1-100.
    // * @param required If required is true, pods will not be scheduled if there is not a match.
    // * @param base object his item will be applied to.
    nodeAffinity(key, values, operator="In", weight=1, required=false, base=k.apps.v1beta2.deployment)::
        if required
            then hidden.requiredNodeAffinity(key, values, operator, base)
            else hidden.preferredNodeAffinity(key, values, weight, operator, base),

    // nodeAffinity creates a pod affinity or anti-affinity
    //
    // * @param key The label key this affinity applies to
    // * @param values An array of string values
    // * @param operator Represents a key's relationship to a set of values. Valid operators are In, NotIn, Exists, DoesNotExist. Gt, and Lt.
    // * @param weight Weight for this affinity in the range 1-100.
    // * @param required If required is true, pods will not be scheduled if there is not a match.
    // * @param anti If anti is true, an anti-affinity will be created.
    // * @param base object his item will be applied to.
    podAffinity(key, values, topology, anti=false, ns=null, required=false, operator="In", weight=1, required=false, base=k.apps.v1beta2.deployment)::
        if required
            then hidden.requiredPodAffinity(key, values, topology, ns, operator, base, anti)
            else hidden.preferredPodAffinity(key, values, topology, weight, ns, operator, base, anti),

    local hidden = {
        affinity(base):: base.mixin.spec.template.spec.affinity,

        withMatchExpression(key, values, operator, nodeSelectorTerms)::
            local matchExpressionsType = nodeSelectorTerms.matchExpressionsType;
            local matchExpressions = matchExpressionsType
                .withKey(key)
                .withValues(values)
                .withOperator(operator);

            nodeSelectorTerms.withMatchExpressions(matchExpressions),

        preferredNodeAffinity(key, values, weight, operator, base)::
            local nodeAffinityType = self.affinity(base).nodeAffinityType;
            local prefType = nodeAffinityType.preferredDuringSchedulingIgnoredDuringExecutionType;
            local createPreference = nodeAffinityType.withPreferredDuringSchedulingIgnoredDuringExecutionMixin;
            local term = self.withMatchExpression(key, values, operator, prefType.mixin.preference)
                + prefType.withWeight(weight);
            local preference = createPreference(term);

            self.affinity(base).nodeAffinity.mixinInstance(preference),

        preferredPodAffinity(key, values, topology, weight, ns, operator, base, anti)::
            local affinity = if anti
                then self.affinity(base).podAntiAffinity
                else self.affinity(base).podAffinity;

            local affinityType = self.affinity(base).podAffinityType;
            local termType = affinityType.preferredDuringSchedulingIgnoredDuringExecutionType;
            local labelSelectorType = termType.mixin.podAffinityTerm.labelSelectorType;
            local matchExpression = self.withMatchExpression(key, values, operator, labelSelectorType);
            local labelSelector = termType.mixin.podAffinityTerm.labelSelector.mixinInstance(matchExpression);

            local weightedTerm = termType.withWeight(weight)
                + termType.mixin.podAffinityTerm.labelSelector.mixinInstance(matchExpression)
                + termType.mixin.podAffinityTerm.withTopologyKey(topology)
                + if ns != null then termType.mixin.podAffinityTerm.withNamespaces(ns) else {};

            affinity.withPreferredDuringSchedulingIgnoredDuringExecutionMixin(weightedTerm),

        requiredPodAffinity(key, values, topology, ns, operator, base, anti)::
            local affinity = if anti
                then self.affinity(base).podAntiAffinity
                else self.affinity(base).podAffinity;

            local affinityType = self.affinity(base).podAffinityType;
            local termType = affinityType.requiredDuringSchedulingIgnoredDuringExecutionType;
            local labelSelectorType = termType.mixin.labelSelectorType;
            local matchExpression = self.withMatchExpression(key, values, operator, labelSelectorType);
            local labelSelector = termType.mixin.podAffinityTerm.labelSelector.mixinInstance(matchExpression);

            local term = termType.withTopologyKey(topology)
                + termType.mixin.labelSelector.mixinInstance(matchExpression)
                + if ns != null then termType.withNamespaces(ns) else {};

            affinity.withRequiredDuringSchedulingIgnoredDuringExecutionMixin(term),

        requiredNodeAffinity(key, values, operator, base)::
            local nodeAffinity = self.affinity(base).nodeAffinity;
            local selectorType = nodeAffinity.requiredDuringSchedulingIgnoredDuringExecutionType;
            local nodeAffinityType = self.affinity(base).nodeAffinityType;
            local nodeSelectorTerms = nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTermsType;
            local term = self.withMatchExpression(key, values, operator, nodeSelectorTerms);

            nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTermsMixin(term),
    },
}