local k = import "k.libsonnet";

{
    nodeAffinity(key, values, operator="In", weight=1, required=false, base=k.apps.v1beta2.deployment)::
        if required
            then hidden.requiredNodeAffinity(key, values, operator, base)
            else hidden.preferredNodeAffinity(key, values, weight, operator, base),

    podAffinity(key, values, required=false, operator="In", version="v1beta2")::
        local affinity = k.apps[version].deployment.mixin.spec.template.spec.affinity;

        {},


    local hidden = {
        affinity(base):: base.mixin.spec.template.spec.affinity,

        schedulerTerm(key, values, operator, nodeSelectorTerms)::
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
            local term = self.schedulerTerm(key, values, operator, prefType.mixin.preference)
                + prefType.withWeight(weight);
            local preference = createPreference(term);

            self.affinity(base).nodeAffinity.mixinInstance(preference),

        requiredNodeAffinity(key, values, operator, base)::
            local nodeAffinity = self.affinity(base).nodeAffinity;
            local selectorType = nodeAffinity.requiredDuringSchedulingIgnoredDuringExecutionType;
            local nodeAffinityType = self.affinity(base).nodeAffinityType;
            local nodeSelectorTerms = nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.nodeSelectorTermsType;
            local term = self.schedulerTerm(key, values, operator, nodeSelectorTerms);

            nodeAffinity.requiredDuringSchedulingIgnoredDuringExecution.withNodeSelectorTermsMixin(term),
    },
}